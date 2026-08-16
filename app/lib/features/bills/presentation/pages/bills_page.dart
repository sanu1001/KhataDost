import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/navigation_cubit.dart';
import '../../../../core/navigation/navigation_state.dart';
import '../../../../core/shell/shell_actions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_skeletons.dart';
import '../../../../core/widgets/empty_state.dart';
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
          titleSpacing: 20,
          actions: [
            IconButton(
              tooltip: 'New bill',
              icon: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              onPressed: () =>
                  context.read<NavigationCubit>().pushNewBill(),
            ),
            const ShellActions(),
          ],
        ),
        // bottom: false — the shell's floating glass bar overlays the list;
        // the list pads itself past it so content scrolls visibly beneath.
        body: SafeArea(
          bottom: false,
          child: BlocBuilder<BillsBloc, BillsState>(
            builder: (context, state) {
              return RefreshIndicator(
                color: AppColors.primary,
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
      return const SkeletonTileList();
    }

    if (state.status == BillsStatus.error && state.bills.isEmpty) {
      // ListView so pull-to-refresh keeps working on the error body.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          EmptyState.error(
            message: state.errorMessage,
            onRetry: () =>
                context.read<BillsBloc>().add(const BillsLoadRequested()),
          ),
        ],
      );
    }

    if (state.bills.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 40),
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No bills yet',
            subtitle: 'Scan the counter or tap + to write the first one.',
            actionLabel: 'New bill',
            onAction: () => context.read<NavigationCubit>().pushNewBill(),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      // Clears the floating glass bar (height injected via extendBody).
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.paddingOf(context).bottom + 12),
      itemCount: state.bills.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _BillTile(bill: state.bills[i]),
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    // Settlement flavor for the badge.
    final String badge;
    final Color badgeColor;
    final Color badgeBg;
    if (bill.isFullyPaid) {
      badge = 'Paid';
      badgeColor = AppColors.success;
      badgeBg = AppColors.successSurface;
    } else if (bill.amountPaid == 0) {
      badge = 'Credit';
      badgeColor = AppColors.error;
      badgeBg = AppColors.errorSurface;
    } else {
      badge = 'Partial';
      badgeColor = AppColors.warning;
      badgeBg = AppColors.warningSurface;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bill.isWalkIn
                  ? AppColors.surfaceVariant
                  : AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              bill.isWalkIn
                  ? Icons.person_off_outlined
                  : Icons.person_outline_rounded,
              size: 20,
              color:
                  bill.isWalkIn ? AppColors.textSecondary : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatBillDate(bill.createdAt),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${formatMoney(bill.amount)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
