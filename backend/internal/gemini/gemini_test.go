package gemini

// White-box tests: the package's own tests may set baseURL/retry on the
// unexported httpClient, so the real HTTP path (request shape, 429 retry,
// schema parsing, sentinel mapping) is exercised against httptest — no
// network, sandbox-safe. The googleapis.com endpoint itself is only ever hit
// from the Bruno real-photo test on Windows.

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// okBody builds a Gemini 200 response whose first part carries the given
// detections array as a STRING — the locked §3 contract.
func okBody(t *testing.T, detectionsJSON string) string {
	t.Helper()
	body, err := json.Marshal(map[string]any{
		"candidates": []map[string]any{{
			"content": map[string]any{
				"parts": []map[string]string{{"text": detectionsJSON}},
			},
		}},
	})
	if err != nil {
		t.Fatalf("marshal ok body: %v", err)
	}
	return string(body)
}

func testClient(srvURL string) *httpClient {
	return &httpClient{
		apiKey:  "test-key",
		baseURL: srvURL,
		hc:      &http.Client{Timeout: 2 * time.Second},
		retry:   0, // no real sleeping in tests
	}
}

func TestDetect_HappyPathAndRequestShape(t *testing.T) {
	var gotPath, gotQuery, gotBody string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		gotQuery = r.URL.RawQuery
		raw, _ := io.ReadAll(r.Body)
		gotBody = string(raw)
		fmt.Fprint(w, okBody(t, `[{"name":"Crisps","brand":"Lays","variant":"Magic Masala","quantity":2,"confidence":0.9}]`))
	}))
	defer srv.Close()

	dets, err := testClient(srv.URL).Detect(context.Background(), "aW1hZ2U=", "image/jpeg")
	if err != nil {
		t.Fatalf("want success, got %v", err)
	}
	if len(dets) != 1 || dets[0].Brand != "Lays" || dets[0].Quantity != 2 || dets[0].Confidence != 0.9 {
		t.Fatalf("detections parsed wrong: %+v", dets)
	}

	// Request shape: key in query, image + prompt + schema in body (§3).
	if gotPath != "/" || !strings.Contains(gotQuery, "key=test-key") {
		t.Fatalf("want ?key=… on the locked URL, got %s?%s", gotPath, gotQuery)
	}
	for _, want := range []string{
		`"inline_data"`, `"mime_type":"image/jpeg"`, `"data":"aW1hZ2U="`,
		`"responseMimeType":"application/json"`, `"responseSchema"`, `"ARRAY"`,
		`"required":["name","quantity"]`, "kirana",
	} {
		if !strings.Contains(gotBody, want) {
			t.Fatalf("request body missing %s:\n%s", want, gotBody)
		}
	}
}

func TestDetect_RateLimitedAfterRetry(t *testing.T) {
	attempts := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		attempts++
		w.WriteHeader(http.StatusTooManyRequests)
	}))
	defer srv.Close()

	_, err := testClient(srv.URL).Detect(context.Background(), "aW1hZ2U=", "image/jpeg")
	if !errors.Is(err, ErrRateLimited) {
		t.Fatalf("want ErrRateLimited, got %v", err)
	}
	if attempts != 2 {
		t.Fatalf("want exactly 2 attempts (one micro-retry), got %d", attempts)
	}
}

func TestDetect_RetryRecovers(t *testing.T) {
	attempts := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		attempts++
		if attempts == 1 {
			w.Header().Set("Retry-After", "1")
			w.WriteHeader(http.StatusTooManyRequests)
			return
		}
		fmt.Fprint(w, okBody(t, `[]`))
	}))
	defer srv.Close()

	dets, err := testClient(srv.URL).Detect(context.Background(), "aW1hZ2U=", "image/jpeg")
	if err != nil {
		t.Fatalf("want recovery on retry, got %v", err)
	}
	if attempts != 2 || len(dets) != 0 {
		t.Fatalf("want 2 attempts and empty detections, got %d / %+v", attempts, dets)
	}
}

func TestDetect_UpstreamFailures(t *testing.T) {
	cases := []struct {
		name    string
		handler http.HandlerFunc
	}{
		{"500", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusInternalServerError) }},
		{"unparseable envelope", func(w http.ResponseWriter, r *http.Request) { fmt.Fprint(w, `{nope`) }},
		{"empty candidates", func(w http.ResponseWriter, r *http.Request) { fmt.Fprint(w, `{"candidates":[]}`) }},
		{"prose instead of schema JSON", func(w http.ResponseWriter, r *http.Request) {
			fmt.Fprint(w, okBody(t, "Sure! Here are the products I found:"))
		}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			srv := httptest.NewServer(tc.handler)
			defer srv.Close()
			_, err := testClient(srv.URL).Detect(context.Background(), "aW1hZ2U=", "image/jpeg")
			if !errors.Is(err, ErrUpstream) {
				t.Fatalf("want ErrUpstream, got %v", err)
			}
		})
	}
}

func TestDetect_Timeout(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(200 * time.Millisecond)
		fmt.Fprint(w, okBody(t, `[]`))
	}))
	defer srv.Close()

	c := testClient(srv.URL)
	c.hc.Timeout = 20 * time.Millisecond
	_, err := c.Detect(context.Background(), "aW1hZ2U=", "image/jpeg")
	if !errors.Is(err, ErrTimeout) {
		t.Fatalf("want ErrTimeout, got %v", err)
	}
}

func TestDetect_ContextDeadline(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(200 * time.Millisecond)
		fmt.Fprint(w, okBody(t, `[]`))
	}))
	defer srv.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
	defer cancel()
	_, err := testClient(srv.URL).Detect(ctx, "aW1hZ2U=", "image/jpeg")
	if !errors.Is(err, ErrTimeout) {
		t.Fatalf("want ErrTimeout on ctx deadline, got %v", err)
	}
}

func TestDetect_NotConfigured(t *testing.T) {
	c := NewClient("")
	_, err := c.Detect(context.Background(), "aW1hZ2U=", "image/jpeg")
	if !errors.Is(err, ErrNotConfigured) {
		t.Fatalf("want ErrNotConfigured with empty key, got %v", err)
	}
}
