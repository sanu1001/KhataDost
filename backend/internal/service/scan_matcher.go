package service

import (
	"strings"
	"unicode"

	"github.com/sanu1001/KhataDost/backend/internal/gemini"
	"github.com/sanu1001/KhataDost/backend/internal/repository"
)

// ── The GATE + MATCH stages of the scan pipeline, as ONE PURE FUNCTION ──────
// No I/O, no clock, no randomness: same detections + same inventory in, same
// result out, every time. That's what makes it table-testable in the offline
// sandbox while the Gemini call itself stays behind the stubbed interface.

// scanConfidenceGate — the §4 LOCKED internal threshold. Gemini's confidence
// is a self-estimate (confident reads land 0.8–0.9, guesses 0.6–0.7 per the
// §6b spike); below the gate a detection is dropped SILENTLY — the shopkeeper
// adds the item manually, and the number is never shown to anyone. Tunable.
const scanConfidenceGate = 0.8

// ScanMatch is one detection that resolved to an inventory card. Flutter
// drops the card onto the bill at DefaultVariantID (§10: the AI picks the
// CARD, the shopkeeper picks the variant — by swiping).
type ScanMatch struct {
	DetectedLabel    string                       // what Gemini saw (display/debug)
	DetectedQuantity int                          // pre-fills the line qty (≥ 1)
	Item             *repository.ItemWithVariants // the full card, variants included
	DefaultVariantID string                       // where the card lands
}

// UnmatchedDetection is a gated detection with no card — the shopkeeper turns
// it into a miscellaneous line (or ignores it).
type UnmatchedDetection struct {
	Label    string
	Quantity int
}

// ScanResult — both slices are always non-nil (JSON emits [], never null).
type ScanResult struct {
	Matches   []ScanMatch
	Unmatched []UnmatchedDetection
}

// MatchDetections applies the confidence gate, then keyword-matches each
// surviving detection against THIS user's inventory.
//
// Matching rules (locked in scan.md, derived from decision log §6b/§9/§10):
//
//  1. Match pool = Type A (unit) items with ≥ 1 variant only. Loose goods are
//     manual-only ("no label → no scan"), and only Type A has the default
//     variant the contract promises.
//  2. BRAND FIRST: candidates share ≥ 1 token with the detection's brand.
//     Only if brand is empty or yields nothing do NAME tokens get a turn —
//     name is the fallback, never the key (§6b: the name field is unreliable).
//  3. Among candidates: highest token overlap (brand ∪ name ∪ variant vs the
//     item name) wins; ties break alphabetically. Deterministic.
//  4. A wrong match costs the shopkeeper one tap (§9: every cell editable),
//     so "good enough" is the bar — no fuzzy-distance machinery.
func MatchDetections(detections []gemini.Detection, items []*repository.ItemWithVariants) *ScanResult {
	type poolEntry struct {
		item   *repository.ItemWithVariants
		tokens map[string]struct{}
	}

	// Build the Type A match pool once, with item-name tokens precomputed.
	pool := make([]poolEntry, 0, len(items))
	for _, it := range items {
		if it.PricingType != "unit" || len(it.Variants) == 0 {
			continue
		}
		pool = append(pool, poolEntry{item: it, tokens: tokenize(it.Name)})
	}

	result := &ScanResult{
		Matches:   make([]ScanMatch, 0),
		Unmatched: make([]UnmatchedDetection, 0),
	}

	for _, d := range detections {
		// GATE — below threshold (or missing, since Go zero = 0.0) → silent drop.
		if d.Confidence < scanConfidenceGate {
			continue
		}

		brandTokens := tokenize(d.Brand)
		nameTokens := tokenize(d.Name)
		allTokens := unionTokens(brandTokens, nameTokens, tokenize(d.Variant))

		qty := d.Quantity
		if qty < 1 {
			qty = 1 // a 0-qty pre-fill would be an invalid bill line
		}
		label := detectionLabel(d)

		// Stage 1: brand tokens pick the candidate set.
		candidates := make([]poolEntry, 0)
		for _, p := range pool {
			if overlap(p.tokens, brandTokens) > 0 {
				candidates = append(candidates, p)
			}
		}
		// Stage 2 (fallback only): name tokens, when brand gave nothing.
		if len(candidates) == 0 {
			for _, p := range pool {
				if overlap(p.tokens, nameTokens) > 0 {
					candidates = append(candidates, p)
				}
			}
		}

		if len(candidates) == 0 {
			result.Unmatched = append(result.Unmatched, UnmatchedDetection{Label: label, Quantity: qty})
			continue
		}

		// Score candidates: total overlap desc, then item name asc — written
		// to be independent of input order.
		best := candidates[0]
		bestScore := overlap(best.tokens, allTokens)
		for _, c := range candidates[1:] {
			score := overlap(c.tokens, allTokens)
			if score > bestScore || (score == bestScore && c.item.Name < best.item.Name) {
				best, bestScore = c, score
			}
		}

		result.Matches = append(result.Matches, ScanMatch{
			DetectedLabel:    label,
			DetectedQuantity: qty,
			Item:             best.item,
			DefaultVariantID: defaultVariantID(best.item),
		})
	}

	return result
}

// ── Pure helpers ─────────────────────────────────────────────────────────────

// tokenize: lowercase → apostrophes vanish (so "Lay's" ≡ "Lays") → remaining
// non-alphanumerics become spaces (so "Parle-G" ≡ "Parle G") → token set.
// "Lay's Magic-Masala" → {lays, magic, masala}. Unicode-aware (Hinglish
// inventory names tokenize fine).
func tokenize(s string) map[string]struct{} {
	var b strings.Builder
	for _, r := range strings.ToLower(s) {
		switch {
		case r == '\'' || r == '’':
			// drop: intra-word apostrophes must not split a token
		case unicode.IsLetter(r) || unicode.IsDigit(r):
			b.WriteRune(r)
		default:
			b.WriteRune(' ')
		}
	}
	set := make(map[string]struct{})
	for _, tok := range strings.Fields(b.String()) {
		set[tok] = struct{}{}
	}
	return set
}

func overlap(a, b map[string]struct{}) int {
	if len(b) < len(a) {
		a, b = b, a
	}
	n := 0
	for tok := range a {
		if _, ok := b[tok]; ok {
			n++
		}
	}
	return n
}

func unionTokens(sets ...map[string]struct{}) map[string]struct{} {
	out := make(map[string]struct{})
	for _, s := range sets {
		for tok := range s {
			out[tok] = struct{}{}
		}
	}
	return out
}

// detectionLabel prefers brand (+ variant) — the reliable fields — and falls
// back to name, then variant, so the label is never empty in practice
// (the schema requires name).
func detectionLabel(d gemini.Detection) string {
	brand := strings.TrimSpace(d.Brand)
	variant := strings.TrimSpace(d.Variant)
	if brand != "" {
		if variant != "" {
			return brand + " " + variant
		}
		return brand
	}
	if name := strings.TrimSpace(d.Name); name != "" {
		return name
	}
	return variant
}

// defaultVariantID: the service-enforced invariant is exactly one default per
// unit item (partial unique index backs it); Variants[0] is a defensive
// fallback, not an expected path.
func defaultVariantID(it *repository.ItemWithVariants) string {
	for _, v := range it.Variants {
		if v.IsDefault {
			return v.ID
		}
	}
	return it.Variants[0].ID
}
