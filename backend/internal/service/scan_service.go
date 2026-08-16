package service

import (
	"context"

	"github.com/google/uuid"

	"github.com/sanu1001/KhataDost/backend/internal/gemini"
	"github.com/sanu1001/KhataDost/backend/internal/repository"
)

// ── ScanService — the orchestrator for POST /v1/scan ────────────────────────
// DETECT (gemini, behind the stubbable interface) → GATE+MATCH (the pure
// matcher) → result. No persistence: a scan is a suggestion, not a record —
// the bill only exists once the shopkeeper settles via POST /v1/bills.
//
// No business sentinels live here: image validation is the handler's job
// (decode+validate, per convention), and the gemini sentinels pass through
// this layer unwrapped exactly like repository sentinels do elsewhere.

type ScanService interface {
	Scan(ctx context.Context, userID uuid.UUID, imageBase64, mimeType string) (*ScanResult, error)
}

type scanService struct {
	gemini gemini.Client
	// inventoryRepo is the FROZEN inventory feature's repository, reused
	// read-only (never modified): ListItemsWithVariants supplies the match
	// pool, already scoped to this user — same reuse pattern as billing/khata
	// borrowing customerRepo.
	inventoryRepo repository.InventoryRepository
}

func NewScanService(geminiClient gemini.Client, inventoryRepo repository.InventoryRepository) ScanService {
	return &scanService{gemini: geminiClient, inventoryRepo: inventoryRepo}
}

func (s *scanService) Scan(
	ctx context.Context,
	userID uuid.UUID,
	imageBase64, mimeType string,
) (*ScanResult, error) {
	// 1. DETECT — Gemini first: if the quota is gone, skip the DB round-trip.
	detections, err := s.gemini.Detect(ctx, imageBase64, mimeType)
	if err != nil {
		return nil, err // gemini sentinels pass through; handler maps them
	}

	// 2. This user's inventory = the match pool (frozen repo, read-only).
	items, err := s.inventoryRepo.ListItemsWithVariants(ctx, userID)
	if err != nil {
		return nil, err // unexpected DB failure → handler's 500 fallback
	}

	// 3. GATE + MATCH — pure, deterministic, unit-tested.
	return MatchDetections(detections, items), nil
}
