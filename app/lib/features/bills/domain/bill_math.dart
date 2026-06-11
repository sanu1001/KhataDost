/// Pure bill arithmetic — mirrors the server's money math
/// (backend `billing_service.go`) so the client's live figures agree with
/// what the server will persist. Client math is ADVISORY display only:
/// the server recomputes every money figure at settle and is the source
/// of truth. Both sides round half-away-from-zero at 2 decimals
/// (Dart `round()` == Go `math.Round` semantics).
///
/// No I/O, no clock, no state — unit-tested in
/// `test/features/bills/bill_math_test.dart`.
library;

/// Round to 2 decimal places, half away from zero (Go `math.Round` parity).
double round2(double v) => (v * 100).round() / 100;

/// One line's cost: `quantity × unitPrice`, rounded to money.
/// Quantity is a count for unit/misc lines, a measure (0.750 kg) for loose.
double lineTotal(double quantity, double unitPrice) =>
    round2(quantity * unitPrice);

/// The running bill total: sum of already-rounded line totals, re-rounded
/// to absorb float drift (0.1 + 0.2 style).
double billTotal(Iterable<double> lineTotals) =>
    round2(lineTotals.fold(0.0, (sum, t) => sum + t));

/// "Paying now" pre-fills to the bill total (§12) — a cash sale is one tap.
double payingNowDefault(double billTotal) => billTotal;
