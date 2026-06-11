package handler

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/sanu1001/KhataDost/backend/internal/gemini"
	"github.com/sanu1001/KhataDost/backend/internal/middleware"
	"github.com/sanu1001/KhataDost/backend/internal/repository"
	"github.com/sanu1001/KhataDost/backend/internal/service"
)

// ── Stub ScanService — the seam that keeps these tests offline ──────────────
// The real Gemini client is never constructed here; the handler only sees the
// interface, exactly as in production wiring.
type stubScanService struct {
	res     *service.ScanResult
	err     error
	gotB64  string
	gotMime string
}

func (s *stubScanService) Scan(ctx context.Context, userID uuid.UUID, imageBase64, mimeType string) (*service.ScanResult, error) {
	s.gotB64, s.gotMime = imageBase64, mimeType
	if s.err != nil {
		return nil, s.err
	}
	return s.res, nil
}

// ── Harness: the real RequireAuth in front, like the production router ──────

const testJWTSecret = "scan-handler-test-secret"

func scanServer(svc service.ScanService) http.Handler {
	return middleware.RequireAuth(http.HandlerFunc(NewScanHandler(svc).Scan))
}

func bearerToken(t *testing.T) string {
	t.Helper()
	t.Setenv("JWT_SECRET", testJWTSecret)
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub": uuid.NewString(),
		"exp": time.Now().Add(time.Hour).Unix(),
	})
	signed, err := tok.SignedString([]byte(testJWTSecret))
	if err != nil {
		t.Fatalf("sign test token: %v", err)
	}
	return "Bearer " + signed
}

func postScan(t *testing.T, h http.Handler, auth string, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/v1/scan", strings.NewReader(body))
	if auth != "" {
		req.Header.Set("Authorization", auth)
	}
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func validImageBody(t *testing.T) (string, string) {
	t.Helper()
	b64 := base64.StdEncoding.EncodeToString([]byte("fake-jpeg-bytes"))
	body, err := json.Marshal(map[string]string{"image_base64": b64})
	if err != nil {
		t.Fatalf("marshal body: %v", err)
	}
	return string(body), b64
}

// ── 401 negative (the real middleware does the rejecting) ───────────────────

func TestScanHandler_NoAuth401(t *testing.T) {
	t.Setenv("JWT_SECRET", testJWTSecret)
	h := scanServer(&stubScanService{})

	rec := postScan(t, h, "", `{"image_base64":"aGk="}`)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("want 401, got %d: %s", rec.Code, rec.Body.String())
	}

	rec = postScan(t, h, "Bearer garbage", `{"image_base64":"aGk="}`)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("garbage token: want 401, got %d", rec.Code)
	}
}

// ── Happy path: full response shape ──────────────────────────────────────────

func TestScanHandler_HappyPath(t *testing.T) {
	stub := &stubScanService{
		res: &service.ScanResult{
			Matches: []service.ScanMatch{{
				DetectedLabel:    "Lays Magic Masala",
				DetectedQuantity: 2,
				DefaultVariantID: "var-1",
				Item: &repository.ItemWithVariants{
					Item: repository.Item{ID: "item-1", Name: "Lays", PricingType: "unit"},
					Variants: []repository.Variant{
						{ID: "var-1", Label: "small", Price: 10, IsDefault: true},
					},
				},
			}},
			Unmatched: []service.UnmatchedDetection{{Label: "POP Popcorn", Quantity: 1}},
		},
	}
	h := scanServer(stub)
	auth := bearerToken(t)
	body, b64 := validImageBody(t)

	rec := postScan(t, h, auth, body)
	if rec.Code != http.StatusOK {
		t.Fatalf("want 200, got %d: %s", rec.Code, rec.Body.String())
	}

	// The service must receive the untouched base64 and the defaulted mime.
	if stub.gotB64 != b64 {
		t.Fatal("service must receive the original base64 string")
	}
	if stub.gotMime != "image/jpeg" {
		t.Fatalf("omitted mime_type must default to image/jpeg, got %q", stub.gotMime)
	}

	var resp struct {
		Matches []struct {
			DetectedLabel    string `json:"detected_label"`
			DetectedQuantity int    `json:"detected_quantity"`
			DefaultVariantID string `json:"default_variant_id"`
			Item             struct {
				ID          string `json:"id"`
				Name        string `json:"name"`
				PricingType string `json:"pricing_type"`
				Variants    []struct {
					ID        string  `json:"id"`
					Price     float64 `json:"price"`
					IsDefault bool    `json:"is_default"`
				} `json:"variants"`
			} `json:"item"`
		} `json:"matches"`
		Unmatched []struct {
			Label    string `json:"label"`
			Quantity int    `json:"quantity"`
		} `json:"unmatched"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	m := resp.Matches[0]
	if m.DetectedLabel != "Lays Magic Masala" || m.DetectedQuantity != 2 || m.DefaultVariantID != "var-1" {
		t.Fatalf("match header wrong: %+v", m)
	}
	if m.Item.ID != "item-1" || m.Item.PricingType != "unit" || len(m.Item.Variants) != 1 || m.Item.Variants[0].Price != 10 {
		t.Fatalf("item card wrong (must mirror inventory JSON): %+v", m.Item)
	}
	if resp.Unmatched[0].Label != "POP Popcorn" || resp.Unmatched[0].Quantity != 1 {
		t.Fatalf("unmatched wrong: %+v", resp.Unmatched)
	}
}

func TestScanHandler_EmptyResultEmitsArrays(t *testing.T) {
	h := scanServer(&stubScanService{
		res: &service.ScanResult{
			Matches:   make([]service.ScanMatch, 0),
			Unmatched: make([]service.UnmatchedDetection, 0),
		},
	})
	body, _ := validImageBody(t)

	rec := postScan(t, h, bearerToken(t), body)
	if rec.Code != http.StatusOK {
		t.Fatalf("empty scan is a 200, got %d", rec.Code)
	}
	out := rec.Body.String()
	if !strings.Contains(out, `"matches":[]`) || !strings.Contains(out, `"unmatched":[]`) {
		t.Fatalf("want [] not null for both arrays, got %s", out)
	}
}

// ── 400s: the handler owns decode+validate ───────────────────────────────────

func TestScanHandler_BadRequests(t *testing.T) {
	cases := []struct {
		name string
		body string
		want string
	}{
		{"garbage json", `{not json`, "invalid request body"},
		{"missing image", `{}`, "image_base64 is required"},
		{"invalid base64", `{"image_base64":"!!!not-base64!!!"}`, "not valid base64"},
		{"empty image", `{"image_base64":""}`, "image_base64 is required"},
		{"bad mime", `{"image_base64":"aGk=","mime_type":"image/gif"}`, "unsupported mime_type"},
	}
	h := scanServer(&stubScanService{res: &service.ScanResult{
		Matches:   make([]service.ScanMatch, 0),
		Unmatched: make([]service.UnmatchedDetection, 0),
	}})
	auth := bearerToken(t)

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rec := postScan(t, h, auth, tc.body)
			if rec.Code != http.StatusBadRequest {
				t.Fatalf("want 400, got %d: %s", rec.Code, rec.Body.String())
			}
			if !strings.Contains(rec.Body.String(), tc.want) {
				t.Fatalf("want error containing %q, got %s", tc.want, rec.Body.String())
			}
		})
	}
}

func TestScanHandler_ImageTooLarge(t *testing.T) {
	// 8MB of real bytes — over the 7MB decoded cap, under the 12MB body cap.
	big := base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{0xFF}, 8<<20))
	body, err := json.Marshal(map[string]string{"image_base64": big})
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	h := scanServer(&stubScanService{})

	rec := postScan(t, h, bearerToken(t), string(body))
	if rec.Code != http.StatusBadRequest || !strings.Contains(rec.Body.String(), "image too large") {
		t.Fatalf("want 400 image too large, got %d: %s", rec.Code, rec.Body.String())
	}
}

// ── Gemini sentinel → status mapping (§4 graceful degradation) ──────────────

func TestScanHandler_GeminiErrorMapping(t *testing.T) {
	cases := []struct {
		name       string
		err        error
		wantStatus int
		wantMsg    string
	}{
		{"rate limited → 429", fmt.Errorf("Detect: status 429: %w", gemini.ErrRateLimited), http.StatusTooManyRequests, "scan limit reached"},
		{"timeout → 504", fmt.Errorf("Detect: %w", gemini.ErrTimeout), http.StatusGatewayTimeout, "took too long"},
		{"upstream → 502", fmt.Errorf("Detect: status 500: %w", gemini.ErrUpstream), http.StatusBadGateway, "scan service unavailable"},
		{"not configured → 502", fmt.Errorf("Detect: %w", gemini.ErrNotConfigured), http.StatusBadGateway, "scan service unavailable"},
		{"unknown → 500 fallback", errors.New("boom"), http.StatusInternalServerError, "could not scan image"},
	}
	auth := bearerToken(t)
	body, _ := validImageBody(t)

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rec := postScan(t, scanServer(&stubScanService{err: tc.err}), auth, body)
			if rec.Code != tc.wantStatus {
				t.Fatalf("want %d, got %d: %s", tc.wantStatus, rec.Code, rec.Body.String())
			}
			if !strings.Contains(rec.Body.String(), tc.wantMsg) {
				t.Fatalf("want message containing %q, got %s", tc.wantMsg, rec.Body.String())
			}
		})
	}
}
