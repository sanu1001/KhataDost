package service

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"github.com/sanu1001/KhataDost/backend/internal/repository"
)

// ── Sentinel errors owned by THIS layer (business rules) ────────────────────
// Repository-level errors (ErrDuplicateItemName, ErrItemNotFound,
// ErrVariantNotFound) are defined in the repository and pass THROUGH this
// layer unwrapped — the handler matches them with errors.Is either way.
var (
	// ErrLooseItemNoVariants — a loose (Type B) item cannot have variants.
	ErrLooseItemNoVariants = errors.New("loose-priced items cannot have variants")

	// ErrUnitNeedsVariants — a unit (Type A) item must be created with ≥1 variant.
	ErrUnitNeedsVariants = errors.New("a unit-priced item needs at least one variant")

	// ErrUnitNeedsOneDefault — a unit item must have EXACTLY one default variant.
	ErrUnitNeedsOneDefault = errors.New("a unit-priced item needs exactly one default variant")

	// ErrInvalidPricingType — pricing_type was neither 'unit' nor 'loose'.
	ErrInvalidPricingType = errors.New("pricing_type must be 'unit' or 'loose'")

	ErrLooseNeedsRateUnit = errors.New("a loose-priced item needs a rate and unit")
)

// ── Params (named structs, per naming convention) ───────────────────────────

// VariantInput is one variant as it arrives on a create request (no id yet —
// the DB generates it). The service hands these to the repo's Variant struct.
type VariantInput struct {
	Label       string
	Price       float64
	IsDefault   bool
	Description *string
}

type CreateItemParams struct {
	Name        string
	PricingType string         // 'unit' | 'loose'
	Rate        *float64       // Type B only
	Unit        *string        // Type B only
	Variants    []VariantInput // Type A only
}

type UpdateItemParams struct {
	Name string
	Rate *float64
	Unit *string
}

type AddVariantParams struct {
	Label       string
	Price       float64
	IsDefault   bool
	Description *string
}

type UpdateVariantParams struct {
	Label       string
	Price       float64
	IsDefault   bool
	Description *string
}

// ── Interface + impl + constructor ──────────────────────────────────────────
type InventoryService interface {
	Create(ctx context.Context, userID uuid.UUID, p CreateItemParams) (*repository.ItemWithVariants, error)
	List(ctx context.Context, userID uuid.UUID) ([]*repository.ItemWithVariants, error)
	UpdateItem(ctx context.Context, id, userID uuid.UUID, p UpdateItemParams) (*repository.Item, error)
	DeleteItem(ctx context.Context, id, userID uuid.UUID) error
	AddVariant(ctx context.Context, itemID, userID uuid.UUID, p AddVariantParams) (*repository.Variant, error)
	UpdateVariant(ctx context.Context, itemID, variantID, userID uuid.UUID, p UpdateVariantParams) (*repository.Variant, error)
	DeleteVariant(ctx context.Context, itemID, variantID, userID uuid.UUID) error
}

type inventoryService struct {
	repo repository.InventoryRepository
}

func NewInventoryService(repo repository.InventoryRepository) InventoryService {
	return &inventoryService{repo: repo}
}

// ── Create — validate type-shape rules, THEN hand off to the repo's tx ──────
func (s *inventoryService) Create(
	ctx context.Context,
	userID uuid.UUID,
	p CreateItemParams,
) (*repository.ItemWithVariants, error) {
	// 1. Validate BEFORE touching the DB. Dispatch on the discriminator.
	if err := validateCreate(p); err != nil {
		return nil, err
	}

	// 2. Map the service's VariantInput → the repo's Variant struct.
	//    (Different layers, different structs — no leaking either direction.)
	variants := make([]repository.Variant, 0, len(p.Variants))
	for _, v := range p.Variants {
		variants = append(variants, repository.Variant{
			Label:       v.Label,
			Price:       v.Price,
			IsDefault:   v.IsDefault,
			Description: v.Description,
		})
	}

	// 3. Hand validated data to the repo's atomic create. Repo owns the tx.
	return s.repo.CreateItemWithVariants(
		ctx, userID, p.Name, p.PricingType, p.Rate, p.Unit, variants,
	)
}

// ── List — pure pass-through (no business rules on read) ────────────────────
func (s *inventoryService) List(ctx context.Context, userID uuid.UUID) ([]*repository.ItemWithVariants, error) {
	return s.repo.ListItemsWithVariants(ctx, userID)
}

// ── UpdateItem — pass-through; repo maps not-found / dup-name sentinels ─────
func (s *inventoryService) UpdateItem(
	ctx context.Context,
	id, userID uuid.UUID,
	p UpdateItemParams,
) (*repository.Item, error) {
	return s.repo.UpdateItem(ctx, id, userID, p.Name, p.Rate, p.Unit)
}

// ── DeleteItem — pass-through; hard delete, CASCADE drops variants ──────────
func (s *inventoryService) DeleteItem(ctx context.Context, id, userID uuid.UUID) error {
	return s.repo.DeleteItem(ctx, id, userID)
}

// ── AddVariant — the VARIANT GUARD (check-then-act, fetch-then-inspect) ─────
// This is the twin of customerService.Delete: fetch the parent, inspect its
// pricing_type, reject if loose, otherwise act. You designed this line-by-line.
//
//  1. s.repo.GetItemByID(ctx, itemID, userID) → fetch parent (proves ownership
//     too: GetItemByID is scoped by user_id, so a foreign item returns
//     ErrItemNotFound). If err != nil, relay it (don't wrap).
//  2. if item.PricingType == "loose" → return nil, ErrLooseItemNoVariants
//  3. else s.repo.CreateVariant(ctx, itemID, p.Label, p.Price, p.IsDefault, p.Description)
func (s *inventoryService) AddVariant(
	ctx context.Context,
	itemID, userID uuid.UUID,
	p AddVariantParams,
) (*repository.Variant, error) {
	item, err := s.repo.GetItemByID(ctx, itemID, userID)
	if err != nil {
		return nil, err
	}
	if item.PricingType == "loose" {
		return nil, ErrLooseItemNoVariants
	}
	return s.repo.CreateVariant(ctx, itemID, p.Label, p.Price, p.IsDefault, p.Description)

}

// ── UpdateVariant — prove parent ownership, then update ─────────────────────
// Variants carry no user_id, so we MUST verify the caller owns the parent item
// before touching the variant (transitive tenancy). Same fetch-first guard.
func (s *inventoryService) UpdateVariant(
	ctx context.Context,
	itemID, variantID, userID uuid.UUID,
	p UpdateVariantParams,
) (*repository.Variant, error) {
	// Ownership gate: if the item isn't this user's, GetItemByID → ErrItemNotFound.
	if _, err := s.repo.GetItemByID(ctx, itemID, userID); err != nil {
		return nil, err
	}
	return s.repo.UpdateVariant(ctx, variantID, p.Label, p.Price, p.IsDefault, p.Description)
}

// ── DeleteVariant — prove parent ownership, then delete ─────────────────────
func (s *inventoryService) DeleteVariant(ctx context.Context, itemID, variantID, userID uuid.UUID) error {
	if _, err := s.repo.GetItemByID(ctx, itemID, userID); err != nil {
		return err
	}
	return s.repo.DeleteVariant(ctx, variantID)
}

// ── Validation — pure functions, dispatched on the discriminator ────────────
// These take ONLY request data (no ctx, no repo, no state) → they're pure and
// unit-testable in isolation, exactly like CustomerSearchIndex.query. Each owns
// ONE pricing type's rules; adding a third type later = add a function, don't
// touch these (open/closed).

// validateCreate routes to the right per-type validator.
func validateCreate(p CreateItemParams) error {
	switch p.PricingType {
	case "unit":
		return validateUnitItem(p)
	case "loose":
		return validateLooseItem(p)
	default:
		return ErrInvalidPricingType
	}
}

// validateUnitItem (Type A): ≥1 variant, EXACTLY one default.
// (rate/unit being non-nil on a unit item is ignored — the repo passes the
// service's values through, and Create doesn't forward rate/unit for unit items
// anyway since they're conceptually N/A. We validate the variant invariants,
// which are the ones that matter for correctness.)
func validateUnitItem(p CreateItemParams) error {
	if len(p.Variants) == 0 {
		return ErrUnitNeedsVariants
	}

	// Count defaults — must be EXACTLY one.
	defaults := 0
	for _, v := range p.Variants {
		if v.IsDefault {
			defaults++
		}
	}
	if defaults != 1 {
		return ErrUnitNeedsOneDefault
	}

	return nil
}

// validateLooseItem (Type B): rate + unit required, NO variants allowed.
func validateLooseItem(p CreateItemParams) error {
	if p.Rate == nil || p.Unit == nil {
		return ErrLooseNeedsRateUnit
	}
	if len(p.Variants) > 0 {
		return ErrLooseItemNoVariants
	}
	return nil
}
