// Package gemini is the infra adapter for Google's Gemini vision API — the
// scan feature's DETECT stage. It is deliberately shaped like internal/db: an
// external dependency behind a small interface, so the service layer depends
// on `Client` (stubbable, sandbox-friendly) and only main.go constructs the
// real HTTP implementation.
//
// The wire contract is LOCKED in the Scan → Bill decision log (§3, validated
// by the §6b spike): gemini-2.5-flash, base64 inline_data + prompt,
// responseMimeType application/json + responseSchema, and the detections
// array arriving as a STRING at candidates[0].content.parts[0].text.
package gemini

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"strconv"
	"time"
)

// ── Sentinel errors (cross the package boundary like repository sentinels) ──
// The service passes these through unwrapped; the handler maps them to
// statuses (429 / 504 / 502) with errors.Is — same pattern as repo errors.
var (
	// ErrNotConfigured — GEMINI_API_KEY is missing. The server boots without
	// it (every other feature works); only /v1/scan degrades.
	ErrNotConfigured = errors.New("gemini api key is not configured")

	// ErrRateLimited — Gemini returned 429 RESOURCE_EXHAUSTED (free tier:
	// 10 RPM / 250 RPD per Google Cloud PROJECT — the §4 scaling cliff).
	ErrRateLimited = errors.New("gemini rate limit reached")

	// ErrTimeout — the call exceeded its deadline or the caller went away.
	ErrTimeout = errors.New("gemini call timed out")

	// ErrUpstream — any other Gemini-side failure: non-200, unreachable,
	// or a response that doesn't honour the schema.
	ErrUpstream = errors.New("gemini upstream failure")
)

// Detection is one product Gemini saw. Field reliability per the §6b spike:
// `Brand` is the trustworthy key (~100%); `Name` is INCONSISTENT (brand,
// category, or product-line at random — "Pringles" / "Crisps" / "Salty
// Snacks") and must never be the primary match key; `Confidence` is a
// self-estimate, used only as an internal gate, never displayed.
type Detection struct {
	Name       string  `json:"name"`
	Brand      string  `json:"brand"`
	Variant    string  `json:"variant"`
	Quantity   int     `json:"quantity"`
	Confidence float64 `json:"confidence"`
}

// Client is the seam the scan service depends on. The real implementation
// talks HTTP; tests (and the offline sandbox) substitute a stub.
type Client interface {
	Detect(ctx context.Context, imageBase64, mimeType string) ([]Detection, error)
}

// ── Locked request constants ─────────────────────────────────────────────────

const defaultBaseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

// detectionPrompt — kept short on purpose (the spike measured ~63 prompt
// tokens; the binding free-tier limit is requests/day, not tokens).
const detectionPrompt = "This is a photo of retail products on the counter of a small Indian " +
	"grocery (kirana) shop. Identify every distinct physical retail product. For each " +
	"return: name (the product name as printed on the packaging), brand (the brand name " +
	"only), variant (size, weight, flavour or pack descriptor if visible, e.g. \"Magic " +
	"Masala 50g\"), quantity (how many units of that exact product appear in the photo), " +
	"and confidence (0 to 1, how certain you are of the identification). Ignore shelves, " +
	"hands, furniture and background objects."

// responseSchemaJSON is the §3 contract verbatim — schema-enforced output is
// what lets Detect json.Unmarshal the reply with no prose-scraping.
const responseSchemaJSON = `{
  "type": "ARRAY",
  "items": {
    "type": "OBJECT",
    "properties": {
      "name":       { "type": "STRING" },
      "brand":      { "type": "STRING" },
      "variant":    { "type": "STRING" },
      "quantity":   { "type": "INTEGER" },
      "confidence": { "type": "NUMBER" }
    },
    "required": ["name", "quantity"]
  }
}`

// ── Wire structs (request) ───────────────────────────────────────────────────

type generateRequest struct {
	Contents         []content        `json:"contents"`
	GenerationConfig generationConfig `json:"generationConfig"`
}

type content struct {
	Parts []part `json:"parts"`
}

// part is a union: exactly one of InlineData / Text is set per part.
type part struct {
	InlineData *inlineData `json:"inline_data,omitempty"`
	Text       string      `json:"text,omitempty"`
}

type inlineData struct {
	MimeType string `json:"mime_type"`
	Data     string `json:"data"`
}

type generationConfig struct {
	ResponseMimeType string          `json:"responseMimeType"`
	ResponseSchema   json.RawMessage `json:"responseSchema"`
}

// ── Wire structs (response) ──────────────────────────────────────────────────

type generateResponse struct {
	Candidates []struct {
		Content struct {
			Parts []struct {
				Text string `json:"text"`
			} `json:"parts"`
		} `json:"content"`
	} `json:"candidates"`
}

// ── HTTP implementation ──────────────────────────────────────────────────────

type httpClient struct {
	apiKey  string
	baseURL string        // overridable in-package for httptest
	hc      *http.Client  // owns the 30s cap (spike calls took seconds)
	retry   time.Duration // wait before the single 429 retry
}

// NewClient builds the real Gemini client. An empty key is allowed — the
// server must boot without scan (main.go logs a warning); Detect then fails
// fast with ErrNotConfigured.
func NewClient(apiKey string) Client {
	return &httpClient{
		apiKey:  apiKey,
		baseURL: defaultBaseURL,
		hc:      &http.Client{Timeout: 30 * time.Second},
		retry:   1500 * time.Millisecond,
	}
}

// Detect sends the image + prompt + schema and returns the parsed detections.
//
// Resilience (§4): one in-request micro-retry on 429 (honouring a sane
// Retry-After), then fail fast and friendly — real backoff is the shopkeeper
// tapping "try again"; the endpoint must not hold the counter hostage.
func (c *httpClient) Detect(ctx context.Context, imageBase64, mimeType string) ([]Detection, error) {
	if c.apiKey == "" {
		return nil, fmt.Errorf("Detect: %w", ErrNotConfigured)
	}

	body, err := json.Marshal(generateRequest{
		Contents: []content{{
			Parts: []part{
				{InlineData: &inlineData{MimeType: mimeType, Data: imageBase64}},
				{Text: detectionPrompt},
			},
		}},
		GenerationConfig: generationConfig{
			ResponseMimeType: "application/json",
			ResponseSchema:   json.RawMessage(responseSchemaJSON),
		},
	})
	if err != nil {
		return nil, fmt.Errorf("Detect marshal: %w", err)
	}

	// Attempt loop: at most 2 tries, the second only after a 429.
	const maxAttempts = 2
	for attempt := 1; ; attempt++ {
		detections, retryAfter, err := c.doOnce(ctx, body, mimeType)
		if err == nil {
			return detections, nil
		}
		if !errors.Is(err, ErrRateLimited) || attempt >= maxAttempts {
			return nil, err
		}
		// Micro-backoff before the one retry, respecting the caller's ctx.
		wait := c.retry
		if retryAfter > 0 && retryAfter <= 3*time.Second {
			wait = retryAfter
		}
		select {
		case <-ctx.Done():
			return nil, fmt.Errorf("Detect: %w", ErrTimeout)
		case <-time.After(wait):
		}
	}
}

// doOnce performs a single HTTP round-trip. On 429 it also reports the parsed
// Retry-After (0 if absent/garbage) so the caller can size its backoff.
func (c *httpClient) doOnce(ctx context.Context, body []byte, mimeType string) ([]Detection, time.Duration, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"?key="+c.apiKey, bytes.NewReader(body))
	if err != nil {
		return nil, 0, fmt.Errorf("Detect request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.hc.Do(req)
	if err != nil {
		if isTimeoutErr(err) {
			return nil, 0, fmt.Errorf("Detect: %w", ErrTimeout)
		}
		return nil, 0, fmt.Errorf("Detect: %w: %v", ErrUpstream, err)
	}
	defer resp.Body.Close()

	// Output is ~2.6k tokens (§6b); 10MB is a generous ceiling, not a limit.
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 10<<20))
	if err != nil {
		if isTimeoutErr(err) {
			return nil, 0, fmt.Errorf("Detect read: %w", ErrTimeout)
		}
		return nil, 0, fmt.Errorf("Detect read: %w: %v", ErrUpstream, err)
	}

	switch {
	case resp.StatusCode == http.StatusTooManyRequests:
		return nil, parseRetryAfter(resp.Header.Get("Retry-After")), fmt.Errorf("Detect: status 429: %w", ErrRateLimited)
	case resp.StatusCode != http.StatusOK:
		return nil, 0, fmt.Errorf("Detect: status %d: %w", resp.StatusCode, ErrUpstream)
	}

	var gr generateResponse
	if err := json.Unmarshal(raw, &gr); err != nil {
		return nil, 0, fmt.Errorf("Detect decode: %w: %v", ErrUpstream, err)
	}
	if len(gr.Candidates) == 0 || len(gr.Candidates[0].Content.Parts) == 0 {
		return nil, 0, fmt.Errorf("Detect: empty candidates: %w", ErrUpstream)
	}

	// The schema-enforced JSON array arrives as a STRING in the first part.
	var detections []Detection
	if err := json.Unmarshal([]byte(gr.Candidates[0].Content.Parts[0].Text), &detections); err != nil {
		return nil, 0, fmt.Errorf("Detect parse detections: %w: %v", ErrUpstream, err)
	}
	return detections, 0, nil
}

// isTimeoutErr — deadline, cancellation, or a net-level timeout all map to
// ErrTimeout: in every case the answer is "try again", not "scan is broken".
func isTimeoutErr(err error) bool {
	if errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) {
		return true
	}
	var ne net.Error
	return errors.As(err, &ne) && ne.Timeout()
}

// parseRetryAfter handles the seconds form only (Gemini's). Garbage → 0.
func parseRetryAfter(h string) time.Duration {
	if h == "" {
		return 0
	}
	secs, err := strconv.Atoi(h)
	if err != nil || secs < 0 {
		return 0
	}
	return time.Duration(secs) * time.Second
}
