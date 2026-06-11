import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/navigation_cubit.dart';
import '../../../../core/navigation/navigation_state.dart';
import '../../../../core/shell/shell_actions.dart';
import '../../domain/entities/bill.dart';
import '../bloc/bills_bloc.dart';
import 'widgets/formats.dart';

/// Bills tab — sales history ("what did I sell?"), newest first, plus the
/// manual on-ramp (+ → new bill). The dues side lives in khata (Phase 5).
class BillsPage extends StatefulWidget {
  const BillsPage({super.key});

  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  void _requestLoad() {
    context.read<BillsBloc>().add(const BillsLoadRequested());
  }

  @override
  void initState() {
    super.initState();
    _requestLoad();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationCubit, NavigationState>(
      // Re-tap of the Bills tab (index 1) → refetch, same as dashboard.
      listenWhen: (prev, curr) =>
          curr.activeTabIndex == 1 && prev.refreshTick != curr.refreshTick,
      listener: (context, _) => _requestLoad(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bills'),
          centerTitle: false,
          actions: [
            IconButton(
              tooltip: 'New bill',
              icon: const Icon(Icons.add),
              onPressed: () =>
                  context.read<NavigationCubit>().pushNewBill(),
            ),
            const ShellActions(),
          ],
        ),
        body: SafeArea(
          child: BlocBuilder<BillsBloc, BillsState>(
            builder: (context, state) {
              return RefreshIndicator(
                onRefresh: () async {
                  _requestLoad();
                  await context
                      .read<BillsBloc>()
                      .stream
                      .firstWhere((s) => !s.isLoading);
                },
                child: _BillsBody(state: state),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BillsBody extends StatelessWidget {
  const _BillsBody({required this.state});

  final BillsState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.bills.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == BillsStatus.error && state.bills.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(child: Text(state.errorMessage ?? 'Could not load bills')),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
              onPressed: () =>
                  context.read<BillsBloc>().add(const BillsLoadRequested()),
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (state.bills.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Icon(Icons.receipt_long_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 12),
          const Center(
            child: Text('No bills yet',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Scan the counter or tap + to write the first one.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: () =>
                  context.read<NavigationCubit>().pushNewBill(),
              icon: const Icon(Icons.add),
              label: const Text('New bill'),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.bills.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) => _BillTile(bill: state.bills[i]),
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Settlement flavor for the badge.
    final String badge;
    final Color badgeColor;
    if (bill.isFullyPaid) {
      badge = 'Paid';
      badgeColor = Colors.green.shade700;
    } else if (bill.amountPaid == 0) {
      badge = 'Credit';
      badgeColor = scheme.error;
    } else {
      badge = 'Partial';
      badgeColor = Colors.orange.shade800;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: Icon(
          bill.isWalkIn ? Icons.person_off_outlined : Icons.person_outline,
          size: 20,
          color: scheme.onSecondaryContainer,
        ),
      ),
      title: Text(bill.customerName,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(formatBillDate(bill.createdAt)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('₹${formatMoney(bill.amount)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15)),
          Text(badge,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: badgeColor)),
        ],
      ),
    );
  }
}
