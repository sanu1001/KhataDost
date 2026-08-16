/// Pure ledger arithmetic — mirrors the server's khata math
/// (`khata_service.go` / the balance SQL) so client figures agree with
/// what the server derives. Client math is ADVISORY display only: the
/// balance shown in the header is the SERVER's; these functions feed the
/// timeline's running-balance column and the Record Payment preflight.
///
/// THE INTEGRITY RULE (§12): balance is DERIVED (Σcredit − Σpayment),
/// never stored, never typed. Nothing in this file mutates anything.
///
/// No I/O, no clock, no state — unit-tested in
/// `test/features/khata/khata_math_test.dart`.
library;

import '../../bills/domain/bill_math.dart' as bm;
import 'entities/khata_entry.dart';

/// The server's exact 400 message (`service.ErrNonPositivePayment`) —
/// the mock and the client preflight reuse it verbatim so the inline
/// error UX is identical offline and online.
const String nonPositivePaymentMessage =
    'payment amount must be greater than zero';

/// An entry's effect on the balance: credit pushes up, payment pulls
/// down (§11). Amounts are stored positive; the sign lives in the type.
double signedAmount(KhataEntry e) => e.isCredit ? e.amount : -e.amount;

/// Derived balance = round2(Σ signed amounts). Same `round2` as billing
/// (half away from zero, Go parity) so money semantics stay identical
/// app-wide. Empty ledger → 0.
double balanceOf(Iterable<KhataEntry> entries) =>
    bm.round2(entries.fold(0.0, (sum, e) => sum + signedAmount(e)));

/// Per-entry running balance for the timeline: [entries] oldest first
/// (the server's order), `out[i]` = balance AFTER `entries[i]`. Each step
/// re-rounds to absorb float drift. The page reverses BOTH lists together
/// for newest-first display.
List<double> runningBalances(List<KhataEntry> entries) {
  final out = <double>[];
  var acc = 0.0;
  for (final e in entries) {
    acc = bm.round2(acc + signedAmount(e));
    out.add(acc);
  }
  return out;
}

/// Record Payment preflight — mirrors the server rule (amount must be
/// > 0). Returns null when valid, else the EXACT server message for
/// inline display. null [amount] = unparseable text field. The server
/// remains the authority; this just saves a doomed round-trip.
String? paymentValidationError(double? amount) {
  if (amount == null || amount <= 0) return nonPositivePaymentMessage;
  return null;
}
