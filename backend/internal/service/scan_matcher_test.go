package service

import (
	"testing"

	"github.com/sanu1001/KhataDost/backend/internal/gemini"
	"github.com/sanu1001/KhataDost/backend/internal/repository"
)

// ── Builders ─────────────────────────────────────────────────────────────────

func unitItem(name string, variants ...repository.Variant) *repository.ItemWithVariants {
	return &repository.ItemWithVariants{
		Item:     repository.Item{ID: "item-" + name, Name: name, PricingType: "unit"},
		Variants: variants,
	}
}

func looseItem(name string) *repository.ItemWithVariants {
	rate, unit := 20.0, "kg"
	return &repository.ItemWithVariants{
		Item:     repository.Item{ID: "item-" + name, Name: name, PricingType: "loose", Rate: &rate, Unit: &unit},
		Variants: []repository.Variant{},
	}
}

func variant(id string, isDefault bool) repository.Variant {
	return repository.Variant{ID: id, Label: id, Price: 10, IsDefault: isDefault}
}

func det(name, brand, variantStr string, qty int, conf float64) gemini.Detection {
	return gemini.Detection{Name: name, Brand: brand, Variant: variantStr, Quantity: qty, Confidence: conf}
}

// ── The gate ─────────────────────────────────────────────────────────────────

func TestMatchDetections_Gate(t *testing.T) {
	items := []*repository.ItemWithVariants{unitItem("Lays", variant("v1", true))}

	t.Run("below gate is dropped silently — not even unmatched", func(t *testing.T) {
		res := MatchDetections([]gemini.Detection{det("Lays", "Lays", "", 1, 0.6)}, items)
		if len(res.Matches) != 0 || len(res.Unmatched) != 0 {
			t.Fatalf("want silent drop, got %d matches / %d unmatched", len(res.Matches), len(res.Unmatched))
		}
	})

	t.Run("missing confidence (zero value) is dropped", func(t *testing.T) {
		res := MatchDetections([]gemini.Detection{det("Lays", "Lays", "", 1, 0)}, items)
		if len(res.Matches) != 0 || len(res.Unmatched) != 0 {
			t.Fatalf("want silent drop, got %d matches / %d unmatched", len(res.Matches), len(res.Unmatched))
		}
	})

	t.Run("exactly at gate passes", func(t *testing.T) {
		res := MatchDetections([]gemini.Detection{det("Lays", "Lays", "", 1, 0.8)}, items)
		if len(res.Matches) != 1 {
			t.Fatalf("want 1 match at the 0.8 boundary, got %d", len(res.Matches))
		}
	})
}

// ── Brand-first matching (§6b: name is never the key) ───────────────────────

func TestMatchDetections_BrandFirst(t *testing.T) {
	t.Run("brand token matches the item", func(t *testing.T) {
		items := []*repository.ItemWithVariants{unitItem("Lays", variant("v1", true))}
		res := MatchDetections([]gemini.Detection{det("Salty Snacks", "Lays", "Magic Masala", 2, 0.9)}, items)
		if len(res.Matches) != 1 || res.Matches[0].Item.Name != "Lays" {
			t.Fatalf("want Lays matched via brand, got %+v", res.Matches)
		}
		if res.Matches[0].DetectedQuantity != 2 {
			t.Fatalf("want quantity 2 preserved, got %d", res.Matches[0].DetectedQuantity)
		}
	})

	t.Run("normalization bridges punctuation: Lay's → Lays", func(t *testing.T) {
		items := []*repository.ItemWithVariants{unitItem("Lays", variant("v1", true))}
		res := MatchDetections([]gemini.Detection{det("Crisps", "Lay's", "", 1, 0.9)}, items)
		if len(res.Matches) != 1 || res.Matches[0].Item.Name != "Lays" {
			t.Fatalf("want Lay's → Lays, got %+v", res.Matches)
		}
	})

	t.Run("brand candidates win even when name points elsewhere", func(t *testing.T) {
		items := []*repository.ItemWithVariants{
			unitItem("Colgate", variant("v1", true)),
			unitItem("Toothpaste Plus", variant("v2", true)),
		}
		res := MatchDetections([]gemini.Detection{det("Toothpaste", "Colgate", "", 1, 0.9)}, items)
		if len(res.Matches) != 1 || res.Matches[0].Item.Name != "Colgate" {
			t.Fatalf("brand must outrank name; got %+v", res.Matches)
		}
	})

	t.Run("name is the fallback when brand is empty", func(t *testing.T) {
		items := []*repository.ItemWithVariants{unitItem("Parle-G", variant("v1", true))}
		res := MatchDetections([]gemini.Detection{det("Parle G", "", "", 1, 0.9)}, items)
		if len(res.Matches) != 1 || res.Matches[0].Item.Name != "Parle-G" {
			t.Fatalf("want name-fallback match on Parle-G, got %+v", res.Matches)
		}
	})

	t.Run("name is the fallback when brand finds nothing", func(t *testing.T) {
		items := []*repository.ItemWithVariants{unitItem("Crisps", variant("v1", true))}
		res := MatchDetections([]gemini.Detection{det("Crisps", "Pringles", "", 1, 0.9)}, items)
		if len(res.Matches) != 1 || res.Matches[0].Item.Name != "Crisps" {
			t.Fatalf("want name-fallback match on Crisps, got %+v", res.Matches)
		}
	})
}

// ── Scoring: overlap then alphabetical — deterministic ──────────────────────

func TestMatchDetections_Scoring(t *testing.T) {
	t.Run("higher total token overlap wins", func(t *testing.T) {
		items := []*repository.ItemWithVariants{
			unitItem("Lays", variant("v1", true)),
			unitItem("Lays Classic", variant("v2", true)),
		}
		res := MatchDetections([]gemini.Detection{det("Classic Salted", "Lays", "", 1, 0.9)}, items)
		if len(res.Matches) != 1 || res.Matches[0].Item.Name != "Lays Classic" {
			t.Fatalf("want Lays Classic (overlap 2 beats 1), got %+v", res.Matches)
		}
	})

	t.Run("ties break alphabetically regardless of input order", func(t *testing.T) {
		items := []*repository.ItemWithVariants{
			unitItem("Amul Cheese", variant("v1", true)), // deliberately listed first
			unitItem("Amul Butter", variant("v2", true)),
		}
		res := MatchDetections([]gemini.Detection{det("", "Amul", "", 1, 0.9)}, items)
		if len(res.Matches) != 1 || res.Matches[0].Item.Name != "Amul Butter" {
			t.Fatalf("want alphabetical tie-break → Amul Butter, got %+v", res.Matches)
		}
	})
}

// ── The match pool (Type A only) ─────────────────────────────────────────────

func TestMatchDetections_Pool(t *testing.T) {
	t.Run("loose (Type B) items never match — manual-only per §10", func(t *testing.T) {
		items := []*repository.ItemWithVariants{looseItem("Sugar")}
		res := MatchDetections([]gemini.Detection{det("Sugar", "Sugar", "", 1, 0.9)}, items)
		if len(res.Matches) != 0 {
			t.Fatalf("Type B must be excluded from the pool, got %+v", res.Matches)
		}
		if len(res.Unmatched) != 1 || res.Unmatched[0].Label != "Sugar" {
			t.Fatalf("want Sugar as unmatched label, got %+v", res.Unmatched)
		}
	})

	t.Run("unit item without variants is excluded (defensive)", func(t *testing.T) {
		items := []*repository.ItemWithVariants{unitItem("Ghost")} // no variants
		res := MatchDetections([]gemini.Detection{det("Ghost", "Ghost", "", 1, 0.9)}, items)
		if len(res.Matches) != 0 || len(res.Unmatched) != 1 {
			t.Fatalf("variantless item must not match, got %+v / %+v", res.Matches, res.Unmatched)
		}
	})
}

// ── Default variant resolution ───────────────────────────────────────────────

func TestMatchDetections_DefaultVariant(t *testing.T) {
	t.Run("the is_default variant is picked, wherever it sits", func(t *testing.T) {
		items := []*repository.ItemWithVariants{
			unitItem("Lays", variant("small", false), variant("medium", true), variant("large", false)),
		}
		res := MatchDetections([]gemini.Detection{det("", "Lays", "", 1, 0.9)}, items)
		if len(res.Matches) != 1 || res.Matches[0].DefaultVariantID != "medium" {
			t.Fatalf("want default variant 'medium', got %+v", res.Matches)
		}
	})

	t.Run("no default → first variant (defensive fallback)", func(t *testing.T) {
		items := []*repository.ItemWithVariants{
			unitItem("Lays", variant("small", false), variant("large", false)),
		}
		res := MatchDetections([]gemini.Detection{det("", "Lays", "", 1, 0.9)}, items)
		if len(res.Matches) != 1 || res.Matches[0].DefaultVariantID != "small" {
			t.Fatalf("want fallback to first variant, got %+v", res.Matches)
		}
	})
}

// ── Labels, quantities, shape ────────────────────────────────────────────────

func TestMatchDetections_LabelsAndShape(t *testing.T) {
	t.Run("unmatched label prefers brand + variant over the unreliable name", func(t *testing.T) {
		res := MatchDetections([]gemini.Detection{det("Salty Snacks", "POP", "Popcorn 30g", 1, 0.9)}, nil)
		if len(res.Unmatched) != 1 || res.Unmatched[0].Label != "POP Popcorn 30g" {
			t.Fatalf("want label 'POP Popcorn 30g', got %+v", res.Unmatched)
		}
	})

	t.Run("unmatched label falls back to name when brand is empty", func(t *testing.T) {
		res := MatchDetections([]gemini.Detection{det("Mystery Thing", "", "", 1, 0.9)}, nil)
		if len(res.Unmatched) != 1 || res.Unmatched[0].Label != "Mystery Thing" {
			t.Fatalf("want label 'Mystery Thing', got %+v", res.Unmatched)
		}
	})

	t.Run("zero/negative quantity clamps to 1 — a 0-qty bill line is invalid", func(t *testing.T) {
		items := []*repository.ItemWithVariants{unitItem("Lays", variant("v1", true))}
		res := MatchDetections([]gemini.Detection{det("", "Lays", "", 0, 0.9)}, items)
		if len(res.Matches) != 1 || res.Matches[0].DetectedQuantity != 1 {
			t.Fatalf("want quantity clamped to 1, got %+v", res.Matches)
		}
	})

	t.Run("empty input → empty NON-NIL slices (JSON [] not null)", func(t *testing.T) {
		res := MatchDetections(nil, nil)
		if res.Matches == nil || res.Unmatched == nil {
			t.Fatal("slices must be non-nil so JSON emits []")
		}
		if len(res.Matches) != 0 || len(res.Unmatched) != 0 {
			t.Fatalf("want empty result, got %+v", res)
		}
	})
}

// ── tokenize (the normalization everything rests on) ────────────────────────

func TestTokenize(t *testing.T) {
	got := tokenize("Lay's Magic-Masala 50g")
	want := []string{"lays", "magic", "masala", "50g"}
	if len(got) != len(want) {
		t.Fatalf("want %d tokens %v, got %v", len(want), want, got)
	}
	for _, tok := range want {
		if _, ok := got[tok]; !ok {
			t.Fatalf("missing token %q in %v", tok, got)
		}
	}
	if len(tokenize("  --  ")) != 0 {
		t.Fatal("punctuation-only input must tokenize to nothing")
	}
}
