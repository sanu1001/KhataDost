import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../bills/presentation/pages/widgets/formats.dart';
import '../../bloc/khata_bloc.dart';

/// A tapped credit entry's bill, receipt-style — READ-ONLY reuse of
/// billing's `getBillById` contract through [KhataBloc] (billing pages
/// untouched). Lives inside features/khata/ by design.
class BillItemsSheet extends StatelessWidget {
  const BillItemsSheet({super.key});

  static Future<void> show(BuildContext context, String billId) {
    final khataBloc = context.read<KhataBloc>();
    khataBloc.add(KhataBillRequested(billId));
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: khataBloc,
        child: const BillItemsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: BlocBuilder<KhataBloc, KhataState>(
        builder: (context, state) {
          final Widget body;
          switch (state.billStatus) {
            case KhataBillStatus.idle:
            case KhataBillStatus.loading:
              body = const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            case KhataBillStatus.error:
              body = Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    state.billError ?? 'Could not load the bill',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            case KhataBillStatus.loaded:
              final bill = state.bill!;
              body = Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.errorSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.receipt_long_outlined,
                              color: AppColors.error, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Credit bill',
                                style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                formatBillDate(bill.createdAt),
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          for (final item in bill.items)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 9),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color:
                                                    AppColors.textPrimary)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${formatQty(item.quantity)} × ₹${formatMoney(item.unitPrice)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text('₹${formatMoney(item.lineTotal)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppColors.textPrimary)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _MoneyRow(label: 'Total', value: bill.amount, bold: true),
                    const SizedBox(height: 6),
                    _MoneyRow(
                      label: 'Paid then',
                      value: bill.amountPaid,
                      color: AppColors.success,
                    ),
                    const SizedBox(height: 6),
                    _MoneyRow(
                      label: 'Went on khata',
                      value: bill.creditAmount,
                      color: AppColors.error,
                    ),
                  ],
                ),
              );
          }

          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [body],
            ),
          );
        },
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  final String label;
  final double value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      fontSize: bold ? 15 : 13.5,
      color: color ?? AppColors.textPrimary,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text('₹${formatMoney(value)}', style: style),
      ],
    );
  }
}
