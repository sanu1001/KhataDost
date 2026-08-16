// Tiny display formatters for the billing screens — no `intl` dependency.

/// ₹ money: always 2 decimals.
String formatMoney(double v) => v.toStringAsFixed(2);

/// Quantities: whole counts render as integers ('2'), measures keep their
/// decimals ('0.75').
String formatQty(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// '11 Jun, 4:32 PM' — compact bill-list timestamp.
String formatBillDate(DateTime dt) {
  final local = dt.toLocal();
  final h24 = local.hour;
  final am = h24 < 12;
  var h = h24 % 12;
  if (h == 0) h = 12;
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_months[local.month - 1]}, $h:$mm ${am ? 'AM' : 'PM'}';
}
