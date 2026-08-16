# Scan — Feature Doc
**Project:** KhataDost
**Status:** Phase 3 (Go backend) built — Flutter capture UI lands in Phase 4
**Scope:** `POST /v1/scan` — bill photo in, matched inventory cards + unmatched labels out. The Gemini call, the confidence gate, and the keyword matcher (Go). No persistence: scanning writes nothing; the bill is only created later via `POST /v1/bills`.

---

## What this feature does

The headline on-ramp: **point camera at the products on the counter → Gemini names them → the backend matches them to THIS user's inventory → Flutter drops the matched cards onto the bill at their default variant.** The AI is a **card-picker, not a price-picker** (decision log §10): it only answers "which item card"; variant/price stays with the shopkeeper (swipe to correct). Unmatched detections come back as labels the shopkeeper can turn into miscellaneous lines. Everything stays editable — a wrong match costs one tap, so the matcher only needs to be *good enough* (§9).

> **Locked in the Scan → Bill decision log (§1–§7, §6b, §10).** Model `gemini-2.5-flash` with `responseMimeType: application/json` + `responseSchema`. The call lives in the **Go backend only** — `GEMINI_API_KEY` sits in `.env` and never ships inside the decompilable Flutter app (§5). Confidence is a self-estimate, used as an internal ≥ 0.8 gate and **never displayed** (§4).

---

## The pipeline (one request, four stages)

```
POST /v1/scan {image_base64, mime_type}
  1. DETECT   gemini.Client.Detect()      image + prompt + schema → []Detection
  2. GATE     confidence < 0.8            → dropped silently (§4 — shopkeeper adds manually)
  3. MATCH    MatchDetections()           pure function vs this user's Type A items
  4. RESPOND  matches (full item cards @ default variant) + unmatched labels
```

Stage 3 reads inventory via the **frozen** `InventoryRepository.ListItemsWithVariants` — read-only reuse, same pattern as billing/khata reusing `customerRepo`. No new SQL, no migration, no sqlc this phase.

## The Gemini contract (validated by the §6b spike)

REST: `POST …/v1beta/models/gemini-2.5-flash:generateContent?key=…` with base64 `inline_data` + prompt, and the locked `responseSchema`: array of `{name, brand, variant, quantity:INTEGER, confidence:NUMBER}`, required `[name, quantity]`. The JSON array arrives as a string at `candidates[0].content.parts[0].text` → `json.Unmarshal` directly (schema enforced cleanly — no prose-scraping).

Spike facts the code leans on: ~3,000 tokens/call means the binding limit is **requests/day (250)**, not tokens; confident reads land 0.8–0.9 vs guesses 0.6–0.7 (confirms the 0.8 gate); **the `name` field is unreliable** — it returns brand, category, or product-line inconsistently ("Pringles" / "Crisps" / "Salty Snacks"), so it is **never the primary match key**.

## Matching rules (pure, deterministic, unit-tested)

`MatchDetections(detections, items)` in `scan_matcher.go` — no I/O, no clock, no randomness:

1. **Normalize** every string the same way: lowercase → non-alphanumerics become spaces → split to a token set ("Lay's Magic Masala" → `{lays, magic, masala}`).
2. **Match pool = this user's Type A (unit) items only.** Loose goods are locked to manual-only (§10: "no label → no scan"), and only Type A has the default variant the response contract promises. A Type B detection ("sugar") simply falls out as unmatched.
3. **Brand first:** candidates = items sharing ≥ 1 token with the detection's `brand`. Only if brand is empty *or* yields zero candidates do `name` tokens get a turn — name is the fallback, **never the key** (§6b).
4. **Scoring among candidates:** highest total token overlap (brand ∪ name ∪ variant tokens vs item-name tokens) wins; ties break alphabetically by item name → same input, same output, always.
5. **Matched** → the full item card (inventory's exact JSON shape) + its default variant id + the detection's label/quantity (Flutter pre-fills qty). **Unmatched** → `{label, quantity}` where label prefers `brand + variant`, falling back to `name`.
6. **No dedupe:** Gemini's own `quantity` covers true duplicates ("2 × same bag"); two distinct Lays bags are two cards — the shopkeeper swipes one of them. (Tunable later if noisy.)

## API

| Endpoint | Status | Notes |
|---|---|---|
| `POST /v1/scan` | 200 | body: `{image_base64, mime_type?}` (mime defaults `image/jpeg`; jpeg/png/webp allowed; decoded size ≤ 7 MB) |

Response:

```json
{
  "matches": [
    {
      "detected_label": "Lays Magic Masala",
      "detected_quantity": 2,
      "default_variant_id": "…",
      "item": { "id": "…", "name": "Lays", "pricing_type": "unit",
                "rate": null, "unit": null,
                "variants": [ { "id": "…", "label": "small", "price": 10, "is_default": true } ] }
    }
  ],
  "unmatched": [ { "label": "POP Popcorn", "quantity": 1 } ]
}
```

`item` mirrors the inventory endpoints' card JSON exactly, so Flutter parses it with the existing Item model. Empty photo / nothing above the gate → 200 with two empty arrays (not an error — the manual on-ramp is always there).

Errors: 400 invalid body / undecodable base64 / unsupported mime / image too large · 401 no/bad token · **429** Gemini quota hit ("scan limit reached, try again in a minute") · **502** upstream failure or unparseable response / key not configured · **504** Gemini timed out. 429/504 are the §4 graceful-degradation cases: the shopkeeper gets a "try again" toast and falls back to manual add; nothing breaks.

## Resilience (§4 caveats, implemented)

- **429 RESOURCE_EXHAUSTED:** one in-request micro-retry (~1.5 s, honoring `Retry-After` when sane) — the free tier is 10 RPM / 250 RPD per *project*, so real backoff is the shopkeeper trying again; the endpoint fails fast and friendly rather than holding the counter hostage.
- **Timeout:** 30 s cap on the Gemini call (spike calls took seconds) → 504.
- **Quota is per Google Cloud project, not per user** — one key serves all shops. Fine for portfolio + one shop; the documented scaling cliff stands.
- **Missing `GEMINI_API_KEY`:** server boots and logs a warning (every other feature works); `/v1/scan` returns 502 until the key lands in `backend/.env`.

### LLD decisions

1. **JSON base64 body, not multipart** — matches every other endpoint's decode+validate pattern, and Gemini wants base64 `inline_data` anyway (zero conversion). A phone JPEG at ~3–5 MB → ~4–7 MB JSON over LAN: fine. `http.MaxBytesReader` (12 MB) guards the body.
2. **`gemini` is its own package** (`internal/gemini`), like `internal/db`: an infra adapter behind a small interface (`Client`, one method `Detect`). The service depends on the interface, so tests stub it and the sandbox (which can't reach googleapis.com) never needs the real thing.
3. **Sentinel errors cross the package boundary** the same way repository errors do: `gemini.ErrRateLimited` / `ErrTimeout` / `ErrUpstream` pass through the service unwrapped; the handler maps them (429/504/502) exactly like `writeBillingError` maps repo sentinels.
4. **The gate lives inside `MatchDetections`** (threshold = package const `0.8`) so the whole detect→gate→match step is one pure, table-testable function.
5. **No persistence** — a scan is a suggestion, not a record. The bill (and khata) only exist once the shopkeeper settles via `POST /v1/bills`. Re-scan costs nothing but quota.

## Layer map (follows the four built features exactly)

- `internal/gemini/gemini.go` — `Detection`, `Client` interface + HTTP impl (`NewClient(apiKey)`), wire structs, retry, sentinels. **NEW package.**
- `internal/service/scan_service.go` — `ScanService` (`Scan`), orchestrates detect → match. No sentinels of its own: image validation is the handler's decode+validate job, and gemini sentinels pass through unwrapped (like repo sentinels elsewhere).
- `internal/service/scan_matcher.go` — the pure matcher + `ScanResult`/`ScanMatch`/`UnmatchedDetection` + gate const.
- `internal/service/scan_matcher_test.go` — table-driven: gate, brand-first, name-fallback, Type B exclusion, tie-break, normalization.
- `internal/handler/scan_handler.go` — decode/validate (base64, mime, size), sentinel→status map, response mapping mirroring the inventory card JSON.
- `internal/handler/scan_handler_test.go` — httptest with a stubbed `ScanService`: 200 shape, 400s, 429 mapping.
- `cmd/api/main.go` — additive: gemini client + scan chain + `POST /v1/scan` in the protected group.
- Bruno: `scan/` folder — Scan Photo (base64 via env var), Scan No Auth 401.
- `.env` — add `GEMINI_API_KEY=…` (key from AI Studio; never committed, never in Flutter).
