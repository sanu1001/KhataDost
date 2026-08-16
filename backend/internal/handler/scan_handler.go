package handler

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"

	"github.com/sanu1001/KhataDost/backend/internal/gemini"
	"github.com/sanu1001/KhataDost/backend/internal/middleware"
	"github.com/sanu1001/KhataDost/backend/internal/service"
)

// ── Size guards ──────────────────────────────────────────────────────────────
// A phone JPEG runs ~3–5 MB; base64 inflates ×4/3. 12 MB of body comfortably
// fits a 7 MB image and stops anything sillier at the door.
const (
	maxScanBodyBytes  = 12 << 20 // raw request body cap (base64 + envelope)
	maxScanImageBytes = 7 << 20  // decoded image cap (Gemini inline_data stays well inside its limit)
)

// allowedScanMimeTypes — what Gemini vision accepts and a phone camera emits.
var allowedScanMimeTypes = map[string]bool{
	"image/jpeg": true,
	"image/png":  true,
	"image/webp": true,
}

// ── Request struct ───────────────────────────────────────────────────────────
// JSON base64 (not multipart): matches every other endpoint's decode+validate
// pattern, and Gemini wants base64 inline_data anyway — zero conversion.
type scanRequest struct {
	ImageBase64 string `json:"image_base64"`
	MimeType    string `json:"mime_type"` // omitted → image/jpeg
}

// ── Response structs ─────────────────────────────────────────────────────────
// Item reuses the inventory feature's itemResponse (same package — additive
// reuse, like writeJSON/writeError) so the card JSON is byte-identical to
// what /v1/inventory emits and Flutter parses it with the existing model.
type scanMatchResponse struct {
	DetectedLabel    string       `json:"detected_label"`
	DetectedQuantity int          `json:"detected_quantity"`
	DefaultVariantID string       `json:"default_variant_id"`
	Item             itemResponse `json:"item"`
}

type scanUnmatchedResponse struct {
	Label    string `json:"label"`
	Quantity int    `json:"quantity"`
}

// Both slices are always non-nil → JSON emits [] (an empty counter photo is a
// 200 with two empty arrays, not an error — the manual on-ramp always works).
type scanResponse struct {
	Matches   []scanMatchResponse   `json:"matches"`
	Unmatched []scanUnmatchedResponse `json:"unmatched"`
}

// ── Handler ─────────────────────────────────────────────────────────────────
type ScanHandler struct {
	scanService service.ScanService
}

func NewScanHandler(scanService service.ScanService) *ScanHandler {
	return &ScanHandler{scanService: scanService}
}

// ── POST /v1/scan — bill photo in, cards + labels out ───────────────────────
func (h *ScanHandler) Scan(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	// Cap the body BEFORE decoding — MaxBytesReader poisons reads past the
	// limit, which json.Decode surfaces as *http.MaxBytesError.
	r.Body = http.MaxBytesReader(w, r.Body, maxScanBodyBytes)

	var req scanRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		var mbe *http.MaxBytesError
		if errors.As(err, &mbe) {
			writeError(w, "image too large (max 7MB)", http.StatusBadRequest)
			return
		}
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}
	if req.ImageBase64 == "" {
		writeError(w, "image_base64 is required", http.StatusBadRequest)
		return
	}

	mimeType := req.MimeType
	if mimeType == "" {
		mimeType = "image/jpeg"
	}
	if !allowedScanMimeTypes[mimeType] {
		writeError(w, "unsupported mime_type (use image/jpeg, image/png or image/webp)", http.StatusBadRequest)
		return
	}

	// Decode purely to VALIDATE (well-formed base64, sane size); the base64
	// string itself is what travels on to Gemini as inline_data.
	raw, err := base64.StdEncoding.DecodeString(req.ImageBase64)
	if err != nil {
		writeError(w, "image_base64 is not valid base64", http.StatusBadRequest)
		return
	}
	if len(raw) == 0 {
		writeError(w, "image is empty", http.StatusBadRequest)
		return
	}
	if len(raw) > maxScanImageBytes {
		writeError(w, "image too large (max 7MB)", http.StatusBadRequest)
		return
	}

	result, err := h.scanService.Scan(r.Context(), userID, req.ImageBase64, mimeType)
	if err != nil {
		writeScanError(w, err, "could not scan image")
		return
	}

	writeJSON(w, toScanResponse(result), http.StatusOK)
}

// ── Sentinel → status mapping ────────────────────────────────────────────────
// The gemini package's sentinels cross the service unwrapped, exactly like
// repository sentinels do in writeBillingError. 429/504 are the §4 graceful
// degradation: a friendly "try again" — the manual on-ramp keeps the counter
// moving; nothing breaks.
func writeScanError(w http.ResponseWriter, err error, fallback string) {
	switch {
	case errors.Is(err, gemini.ErrRateLimited):
		writeError(w, "scan limit reached, try again in a minute", http.StatusTooManyRequests)
	case errors.Is(err, gemini.ErrTimeout):
		writeError(w, "scan took too long, try again", http.StatusGatewayTimeout)
	case errors.Is(err, gemini.ErrNotConfigured), errors.Is(err, gemini.ErrUpstream):
		writeError(w, "scan service unavailable", http.StatusBadGateway)
	default:
		writeError(w, fallback, http.StatusInternalServerError)
	}
}

// ── Mapping helpers ──────────────────────────────────────────────────────────

func toScanResponse(res *service.ScanResult) scanResponse {
	matches := make([]scanMatchResponse, 0, len(res.Matches))
	for _, m := range res.Matches {
		matches = append(matches, scanMatchResponse{
			DetectedLabel:    m.DetectedLabel,
			DetectedQuantity: m.DetectedQuantity,
			DefaultVariantID: m.DefaultVariantID,
			Item:             toItemResponse(m.Item), // inventory's own mapper — contract stays in lockstep
		})
	}
	unmatched := make([]scanUnmatchedResponse, 0, len(res.Unmatched))
	for _, u := range res.Unmatched {
		unmatched = append(unmatched, scanUnmatchedResponse{Label: u.Label, Quantity: u.Quantity})
	}
	return scanResponse{Matches: matches, Unmatched: unmatched}
}
