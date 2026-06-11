import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    final scheme = Theme.of(context).colorScheme;

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
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              );
            case KhataBillStatus.loaded:
              final bill = state.bill!;
              body = Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    Text(
                      'Credit bill — ${formatBillDate(bill.createdAt)}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    for (final item in bill.items) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${formatQty(item.quantity)} × ₹${formatMoney(item.unitPrice)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text('₹${formatMoney(item.lineTotal)}'),
                          ],
                        ),
                      ),
                    ],
                    const Divider(height: 24),
                    _MoneyRow(label: 'Total', value: bill.amount, bold: true),
                    const SizedBox(height: 4),
                    _MoneyRow(label: 'Paid then', value: bill.amountPaid),
                    const SizedBox(height: 4),
                    _MoneyRow(
                      label: 'Went on khata',
                      value: bill.creditAmount,
                      color: scheme.error,
                    ),
                  ],
                ),
              );
          }

          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                body,
              ],
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
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: color,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text('₹${formatMoney(value)}', style: style),
      ],
    );
  }
}
