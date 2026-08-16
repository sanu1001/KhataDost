import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/navigation_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_skeletons.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../bills/presentation/pages/widgets/formats.dart';
import '../../../customers/presentation/bloc/customers_bloc.dart';
import '../../../customers/presentation/bloc/customers_state.dart';
import '../bloc/khata_bloc.dart';
import 'widgets/bill_items_sheet.dart';
import 'widgets/khata_entry_tile.dart';
import 'widgets/record_payment_sheet.dart';

/// The Khata home the customer detail page was always designed to grow
/// into (customers.md §Screens): balance header + entry timeline +
/// Record Payment. The balance shown is the SERVER's derived figure;
/// the per-entry running column is khata_math, recomputed in the bloc.
///
/// Timeline shows the proof trail the shopkeeper can point at (§11) —
/// newest first; credit entries with a live bill link open the bill's
/// items read-only.
class CustomerKhataPage extends StatefulWidget {
  const CustomerKhataPage({super.key, required this.customerId});

  final String customerId;

  @override
  State<CustomerKhataPage> createState() => _CustomerKhataPageState();
}

class _CustomerKhataPageState extends State<CustomerKhataPage> {
  @override
  void initState() {
    super.initState();
    context.read<KhataBloc>().add(KhataLoadRequested(widget.customerId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Customer name from the frozen CustomersBloc (read-only reuse).
        // firstWhereOrNull is covariance-safe (test-only closure) — the
        // detail page uses the same lookup.
        title: BlocBuilder<CustomersBloc, CustomersState>(
          builder: (context, state) {
            final customer = state.customers
                .firstWhereOrNull((c) => c.id == widget.customerId);
            return Text(
              customer != null ? "${customer.name} — Khata" : 'Khata',
            );
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.read<NavigationCubit>().goBack(),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<KhataBloc, KhataState>(
          builder: (context, state) {
            switch (state.status) {
              case KhataStatus.initial:
              case KhataStatus.loading:
                return const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    children: [
                      SkeletonStatCard(height: 124),
                      SizedBox(height: 12),
                      Expanded(
                        child: SkeletonTileList(
                          count: 5,
                          padding: EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                    ],
                  ),
                );

              case KhataStatus.error:
                return EmptyState.error(
                  message: state.errorMessage,
                  onRetry: () => context
                      .read<KhataBloc>()
                      .add(KhataLoadRequested(widget.customerId)),
                );

              case KhataStatus.loaded:
                return Column(
                  children: [
                    _BalanceHeader(state: state),
                    Expanded(
                      child: state.hasEntries
                          ? _Timeline(state: state)
                          : const EmptyState(
                              icon: Icons.menu_book_outlined,
                              title: 'No entries yet',
                              subtitle:
                                  'Credit bills and payments will appear here.',
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => RecordPaymentSheet.show(context),
                          icon: const Icon(Icons.payments_outlined, size: 20),
                          label: const Text('Receive Payment'),
                        ),
                      ),
                    ),
                  ],
                );
            }
          },
        ),
      ),
    );
  }
}

/// The derived balance, big — never typed, only moved by entries (§12).
class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.state});

  final KhataState state;

  @override
  Widget build(BuildContext context) {
    final balance = state.balance;

    final String label;
    final Color amountColor;
    final Color chipBg;
    final IconData chipIcon;
    if (balance > 0) {
      label = 'Owes you';
      amountColor = AppColors.error;
      chipBg = AppColors.errorSurface;
      chipIcon = Icons.trending_up_rounded;
    } else if (balance < 0) {
      label = 'Advance — you owe';
      amountColor = AppColors.primary;
      chipBg = AppColors.primarySurface;
      chipIcon = Icons.trending_down_rounded;
    } else {
      label = 'All settled';
      amountColor = AppColors.success;
      chipBg = AppColors.successSurface;
      chipIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(chipIcon, size: 14, color: amountColor),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '₹${formatMoney(balance.abs())}',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: amountColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Derived from ${state.entries.length} '
            'entr${state.entries.length == 1 ? 'y' : 'ies'} — Σcredit − Σpayments',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

/// Newest first: both lists are reversed TOGETHER so each row keeps its
/// own running balance (they're aligned 1:1 by the bloc).
class _Timeline extends StatelessWidget {
  const _Timeline({required this.state});

  final KhataState state;

  @override
  Widget build(BuildContext context) {
    final n = state.entries.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 2, 20, 8),
          child: Text(
            'Transaction History',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: n,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final entry = state.entries[n - 1 - i];
              final runningBalance = state.runningBalances[n - 1 - i];
              return KhataEntryTile(
                entry: entry,
                runningBalance: runningBalance,
                onTap: entry.hasBill
                    ? () => BillItemsSheet.show(context, entry.billId!)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
