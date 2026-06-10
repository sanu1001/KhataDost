package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"

	"github.com/sanu1001/KhataDost/backend/internal/sqlcgen"
)

// ── Sentinel errors that ORIGINATE in the repository (DB-derived) ───────────
// Business-rule errors (type-shape rules, variant guard) live in the SERVICE
// layer, not here — same split as customers (the dues-check was in the service).
var (
	ErrDuplicateItemName = errors.New("an item with this name already exists")
	ErrItemNotFound      = errors.New("item not found")
	ErrVariantNotFound   = errors.New("variant not found")
)

// ── Domain structs (clean Go types — no database/sql or sqlc leaking out) ───
type Item struct {
	ID          string
	Name        string
	PricingType string
	Rate        *float64 // nil for Type A (unit) — nullable-by-design
	Unit        *string  // nil for Type A
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

type Variant struct {
	ID          string
	Label       string
	Price       float64
	IsDefault   bool
	Description *string // nullable
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// ItemWithVariants = an Item PLUS its variants nested.
// `Item` with no field name is EMBEDDED — its fields are promoted, so you can
// write iwv.Name directly (not iwv.Item.Name). Like a C++ base subobject.
type ItemWithVariants struct {
	Item
	Variants []Variant // empty slice for Type B (loose) — never nil in output
}

// ── Interface + unexported impl + constructor ───────────────────────────────
type InventoryRepository interface {
	CreateItemWithVariants(ctx context.Context, userID uuid.UUID, name, pricingType string, rate *float64, unit *string, variants []Variant) (*ItemWithVariants, error)
	ListItemsWithVariants(ctx context.Context, userID uuid.UUID) ([]*ItemWithVariants, error)
	GetItemByID(ctx context.Context, id, userID uuid.UUID) (*Item, error)
	UpdateItem(ctx context.Context, id, userID uuid.UUID, name string, rate *float64, unit *string) (*Item, error)
	DeleteItem(ctx context.Context, id, userID uuid.UUID) error
	CreateVariant(ctx context.Context, itemID uuid.UUID, label string, price float64, isDefault bool, description *string) (*Variant, error)
	UpdateVariant(ctx context.Context, variantID uuid.UUID, label string, price float64, isDefault bool, description *string) (*Variant, error)
	DeleteVariant(ctx context.Context, variantID uuid.UUID) error
}

type inventoryRepository struct {
	db      *sqlx.DB // ← NEW vs customers: needed for BeginTxx (transaction)
	queries *sqlcgen.Queries
}

func NewInventoryRepository(db *sqlx.DB) InventoryRepository {
	return &inventoryRepository{
		db:      db,
		queries: sqlcgen.New(db),
	}
}

// ── CreateItemWithVariants — the project's first transaction ────────────────
// Inserts the item, then N variants, ALL-OR-NOTHING. The service has already
// validated type-shape rules (≥1 variant, exactly one default, etc.) before we
// get here — this method's only job is atomicity.
func (r *inventoryRepository) CreateItemWithVariants(
	ctx context.Context,
	userID uuid.UUID,
	name, pricingType string,
	rate *float64,
	unit *string,
	variants []Variant,
) (*ItemWithVariants, error) {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("CreateItemWithVariants begin: %w", err)
	}
	defer tx.Rollback() // RAII: undo on any early return; no-op after commit

	// Re-bind sqlc queries to the TRANSACTION handle, not the pool.
	// This is the New(tx) insight: same query funcs, running inside tx.
	qtx := sqlcgen.New(tx)

	// 1. Insert the parent item, get its generated id back.
	itemRow, err := qtx.CreateItem(ctx, sqlcgen.CreateItemParams{
		UserID:      userID,
		Name:        name,
		PricingType: pricingType,
		Rate:        floatToNullString(rate), // *float64 → NUMERIC string or NULL
		Unit:        toNullString(unit),      // reused from customer_repository.go
	})
	if err != nil {
		if isUniqueViolation(err) { // reused helper (23505)
			return nil, ErrDuplicateItemName
		}
		return nil, fmt.Errorf("CreateItemWithVariants item: %w", err)
	}

	// 2. Insert each variant against the just-created item id.
	created := make([]Variant, 0, len(variants))
	for _, v := range variants {
		vRow, err := qtx.CreateVariant(ctx, sqlcgen.CreateVariantParams{
			ItemID:      itemRow.ID, // the parent id from step 1
			Label:       v.Label,
			Price:       floatToString(v.Price), // NUMERIC is NOT NULL here → plain string
			IsDefault:   v.IsDefault,
			Description: toNullString(v.Description),
		})
		if err != nil {
			// deferred Rollback undoes the item + any earlier variants
			return nil, fmt.Errorf("CreateItemWithVariants variant %q: %w", v.Label, err)
		}
		created = append(created, variantToDomain(vRow))
	}

	// 3. Commit. After this, the deferred Rollback becomes a no-op.
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("CreateItemWithVariants commit: %w", err)
	}

	// 4. Assemble the domain object to return (no extra query — we have it all).
	result := &ItemWithVariants{
		Item:     itemToDomain(itemRow),
		Variants: created,
	}
	return result, nil
}

// ── ListItemsWithVariants — the JOIN-grouping method ────────────────────────
// SQL returns FLAT rows (a unit item with 3 variants = 3 rows). This method
// collapses them into nested ItemWithVariants objects, preserving the SQL's
// ORDER BY name via a parallel ordered slice (Go maps have no stable order).
func (r *inventoryRepository) ListItemsWithVariants(
	ctx context.Context,
	userID uuid.UUID,
) ([]*ItemWithVariants, error) {
	rows, err := r.queries.ListItemsWithVariants(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("ListItemsWithVariants: %w", err)
	}

	// byID: fast O(1) parent lookup + dedupe. Holds POINTERS so appending to
	// .Variants mutates the same object the result slice will return.
	byID := make(map[uuid.UUID]*ItemWithVariants)
	// order: records first-sighting position → preserves ORDER BY name.
	order := make([]uuid.UUID, 0)

	for _, row := range rows {
		// 1. Seen this item before? If not, build it and record its position.
		item, ok := byID[row.ItemID]
		if !ok {
			item = &ItemWithVariants{
				Item: Item{
					ID:          row.ItemID.String(),
					Name:        row.ItemName,
					PricingType: row.PricingType,
					Rate:        nullStringToFloatPtr(row.Rate), // NULL → nil (Type A)
					Unit:        fromNullString(row.Unit),       // NULL → nil (Type A)
					CreatedAt:   row.ItemCreatedAt,
					UpdatedAt:   row.ItemUpdatedAt,
				},
				Variants: make([]Variant, 0), // empty, NOT nil — JSON emits [] not null
			}
			byID[row.ItemID] = item
			order = append(order, row.ItemID) // ← ONLY on first sighting
		}

		// 2. Does THIS row carry a variant? LEFT JOIN → loose items have none.
		//    VariantID.Valid is the one true skip-flag (PK present iff a variant
		//    exists). If false, every v.* field is NULL → skip.
		if !row.VariantID.Valid {
			continue
		}

		price, _ := strconv.ParseFloat(row.Price.String, 64) // NOT NULL in DB → safe
		item.Variants = append(item.Variants, Variant{
			ID:          row.VariantID.UUID.String(),
			Label:       row.Label.String,
			Price:       price,
			IsDefault:   row.IsDefault.Bool,
			Description: fromNullString(row.Description),
			CreatedAt:   row.VariantCreatedAt.Time,
			UpdatedAt:   row.VariantUpdatedAt.Time,
		})
	}

	// 3. Rebuild in alphabetical order by walking the order slice.
	result := make([]*ItemWithVariants, 0, len(order))
	for _, id := range order {
		result = append(result, byID[id])
	}
	return result, nil
}

// ── GetItemByID ─────────────────────────────────────────────────────────────
// Twin of your GetCustomerByID. Returns *Item (NO variants attached) — it's the
// variant guard's lookup: the service calls it to read pricing_type before
// allowing a variant insert. Variants aren't needed for that decision.
//
//	sqlc: r.queries.GetItemByID(ctx, sqlcgen.GetItemByIDParams{ID, UserID}) (sqlcgen.Item, error)
//	Map sql.ErrNoRows → ErrItemNotFound. Return *Item via itemToDomain.
func (r *inventoryRepository) GetItemByID(ctx context.Context, id, userID uuid.UUID) (*Item, error) {
	row, err := r.queries.GetItemByID(ctx, sqlcgen.GetItemByIDParams{
		ID:     id,
		UserID: userID,
	})

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrItemNotFound
		}
		return nil, fmt.Errorf("GetItemByID: %w", err)

	}

	item := itemToDomain(row)
	return &item, nil

}

// ── UpdateItem ──────────────────────────────────────────────────────────────
// Update item fields (name, rate, unit), bump updated_at. Scoped by id AND
// user_id. pricing_type is NOT updatable — type is fixed at creation.
func (r *inventoryRepository) UpdateItem(
	ctx context.Context,
	id, userID uuid.UUID,
	name string,
	rate *float64,
	unit *string,
) (*Item, error) {
	row, err := r.queries.UpdateItem(ctx, sqlcgen.UpdateItemParams{
		ID:     id,
		UserID: userID,
		Name:   name,
		Rate:   floatToNullString(rate),
		Unit:   toNullString(unit),
	})
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrItemNotFound
		}
		if isUniqueViolation(err) {
			return nil, ErrDuplicateItemName
		}
		return nil, fmt.Errorf("UpdateItem: %w", err)
	}
	item := itemToDomain(row)
	return &item, nil
}

// ── DeleteItem ──────────────────────────────────────────────────────────────
// Twin of your DeleteCustomer. Hard delete, scoped by id AND user_id.
// ON DELETE CASCADE drops the variants in the DB — nothing extra here.
//
//	sqlc: r.queries.DeleteItem(ctx, sqlcgen.DeleteItemParams{ID, UserID}) error
//	Just wrap the error with %w.
func (r *inventoryRepository) DeleteItem(ctx context.Context, id, userID uuid.UUID) error {
	err := r.queries.DeleteItem(ctx, sqlcgen.DeleteItemParams{
		ID:     id,
		UserID: userID,
	})
	if err != nil {
		return fmt.Errorf("DeleteItem: %w", err)
	}
	return nil
}

// ── CreateVariant ───────────────────────────────────────────────────────────
// Add a single variant to an existing item (the standalone add-variant
// endpoint). NOTE: no user_id scope — variants carry no user_id. Tenancy is
// enforced one layer up: the service calls GetItemByID(itemID, userID) first to
// prove ownership of the parent before this runs.
func (r *inventoryRepository) CreateVariant(
	ctx context.Context,
	itemID uuid.UUID,
	label string,
	price float64,
	isDefault bool,
	description *string,
) (*Variant, error) {
	row, err := r.queries.CreateVariant(ctx, sqlcgen.CreateVariantParams{
		ItemID:      itemID,
		Label:       label,
		Price:       floatToString(price), // NOT NULL NUMERIC → plain string
		IsDefault:   isDefault,
		Description: toNullString(description),
	})
	if err != nil {
		return nil, fmt.Errorf("CreateVariant: %w", err)
	}
	v := variantToDomain(row)
	return &v, nil
}

// ── UpdateVariant ───────────────────────────────────────────────────────────
// Update one variant by its own id. No user_id scope (see CreateVariant note);
// the service proves parent ownership before calling.
func (r *inventoryRepository) UpdateVariant(
	ctx context.Context,
	variantID uuid.UUID,
	label string,
	price float64,
	isDefault bool,
	description *string,
) (*Variant, error) {
	row, err := r.queries.UpdateVariant(ctx, sqlcgen.UpdateVariantParams{
		ID:          variantID,
		Label:       label,
		Price:       floatToString(price),
		IsDefault:   isDefault,
		Description: toNullString(description),
	})
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrVariantNotFound
		}
		return nil, fmt.Errorf("UpdateVariant: %w", err)
	}
	v := variantToDomain(row)
	return &v, nil
}

// ── DeleteVariant ───────────────────────────────────────────────────────────
// Delete one variant by its own id. No user_id scope (see CreateVariant note).
func (r *inventoryRepository) DeleteVariant(ctx context.Context, variantID uuid.UUID) error {
	err := r.queries.DeleteVariant(ctx, variantID)
	if err != nil {
		return fmt.Errorf("DeleteVariant: %w", err)
	}
	return nil
}

// ── Money + mapping helpers (NUMERIC ↔ float) ───────────────────────────────
// toNullString / fromNullString / isUniqueViolation are NOT redefined here —
// they already live in customer_repository.go in this same `repository`
// package, so inventory just calls them.

// floatToString: float64 → string for a NOT-NULL NUMERIC param (variant price).
func floatToString(f float64) string {
	return strconv.FormatFloat(f, 'f', 2, 64) // 'f' = no exponent, 2 decimals
}

// floatToNullString: *float64 → sql.NullString for a NULLABLE NUMERIC (item rate).
// nil → NULL (Type A items have no rate).
func floatToNullString(f *float64) sql.NullString {
	if f == nil {
		return sql.NullString{Valid: false}
	}
	return sql.NullString{String: floatToString(*f), Valid: true}
}

// nullStringToFloatPtr: sql.NullString → *float64. invalid → nil.
func nullStringToFloatPtr(ns sql.NullString) *float64 {
	if !ns.Valid {
		return nil
	}
	f, _ := strconv.ParseFloat(ns.String, 64)
	return &f
}

// itemToDomain: sqlcgen.Item → repository Item (parse NUMERIC, uuid→string).
func itemToDomain(row sqlcgen.Item) Item {
	return Item{
		ID:          row.ID.String(),
		Name:        row.Name,
		PricingType: row.PricingType,
		Rate:        nullStringToFloatPtr(row.Rate), // NULL → nil
		Unit:        fromNullString(row.Unit),       // reused from customers
		CreatedAt:   row.CreatedAt,
		UpdatedAt:   row.UpdatedAt,
	}
}

// variantToDomain: sqlcgen.ItemVariant → repository Variant.
func variantToDomain(row sqlcgen.ItemVariant) Variant {
	price, _ := strconv.ParseFloat(row.Price, 64) // NOT NULL → always parseable
	return Variant{
		ID:          row.ID.String(),
		Label:       row.Label,
		Price:       price,
		IsDefault:   row.IsDefault,
		Description: fromNullString(row.Description),
		CreatedAt:   row.CreatedAt,
		UpdatedAt:   row.UpdatedAt,
	}
}
