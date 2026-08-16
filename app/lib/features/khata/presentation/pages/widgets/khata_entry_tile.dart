import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
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
    final isCredit = entry.isCredit;

    // Credit = dues up (red); payment = money in (green).
    final accent = isCredit ? AppColors.error : AppColors.success;
    final accentBg = isCredit ? AppColors.errorSurface : AppColors.successSurface;

    return Material(
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCredit
                      ? Icons.receipt_long_outlined
                      : Icons.payments_outlined,
                  color: accent,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCredit ? 'Credit' : 'Payment received',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      onTap != null
                          ? '${formatBillDate(entry.createdAt)} · tap for items'
                          : formatBillDate(entry.createdAt),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isCredit ? '+' : '−'}₹${formatMoney(entry.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'bal ₹${formatMoney(runningBalance)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
