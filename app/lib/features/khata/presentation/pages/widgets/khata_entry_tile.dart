import 'package:flutter/material.dart';

import '../../../../bills/presentation/pages/widgets/formats.dart';
import '../../../domain/entities/khata_entry.dart';

/// One timeline row: kind icon, ±amount, date, and the running balance
/// AFTER this entry (the notebook's margin column). Tappable only when
/// the entry has a live bill link ([KhataEntry.hasBill]) — payments and
/// dead-link credits render plain.
class KhataEntryTile extends StatelessWidget {
  const KhataEntryTile({
    super.key,
    required this.entry,
    required this.runningBalance,
    this.onTap,
  });

  final KhataEntry entry;

  /// Balance after this entry (aligned by the bloc with the entry list).
  final double runningBalance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCredit = entry.isCredit;

    // Credit = dues up (error tint); payment = money in (primary tint).
    final accent = isCredit ? scheme.error : scheme.primary;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: accent.withOpacity(0.12),
        child: Icon(
          isCredit ? Icons.receipt_long_outlined : Icons.payments_outlined,
          color: accent,
          size: 20,
        ),
      ),
      title: Text(
        isCredit ? 'Credit' : 'Payment',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        onTap != null
            ? '${formatBillDate(entry.createdAt)} · tap for items'
            : formatBillDate(entry.createdAt),
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${isCredit ? '+' : '−'}₹${formatMoney(entry.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'bal ₹${formatMoney(runningBalance)}',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
