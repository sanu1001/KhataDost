import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/navigation_cubit.dart';
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
                return const Center(child: CircularProgressIndicator());

              case KhataStatus.error:
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.errorMessage ?? 'Could not load khata'),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context
                            .read<KhataBloc>()
                            .add(KhataLoadRequested(widget.customerId)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );

              case KhataStatus.loaded:
                return Column(
                  children: [
                    _BalanceHeader(state: state),
                    const Divider(height: 1),
                    Expanded(
                      child: state.hasEntries
                          ? _Timeline(state: state)
                          : const _EmptyLedger(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => RecordPaymentSheet.show(context),
                          icon: const Icon(Icons.payments_outlined),
                          style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          label: const Text('Record Payment',
                              style: TextStyle(fontSize: 16)),
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
    final scheme = Theme.of(context).colorScheme;
    final balance = state.balance;

    final String label;
    final Color amountColor;
    if (balance > 0) {
      label = 'Owes you';
      amountColor = scheme.error;
    } else if (balance < 0) {
      label = 'Advance — you owe';
      amountColor = scheme.primary;
    } else {
      label = 'All settled';
      amountColor = scheme.onSurfaceVariant;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${formatMoney(balance.abs())}',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: amountColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Derived from ${state.entries.length} '
            'entr${state.entries.length == 1 ? 'y' : 'ies'} — Σcredit − Σpayments',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
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
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: n,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
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
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined,
              size: 48, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          const Text('No entries yet',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Credit bills and payments will appear here',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
