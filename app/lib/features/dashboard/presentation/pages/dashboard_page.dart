import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../auth/bloc/auth_bloc.dart';
import '../../../../core/navigation/navigation_cubit.dart';
import '../../../../core/navigation/navigation_state.dart';
import '../../../../core/shell/shell_actions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  /// Local, UI-only: tap the eye on the sales card to hide the figure
  /// from customers peeking at the counter screen.
  bool _hideAmount = false;

  void _requestLoad() {
    context.read<DashboardBloc>().add(const DashboardLoadRequested());
  }

  @override
  void initState() {
    super.initState();
    _requestLoad();
  }

  /// Placeholder payload rendered under the shimmer on first load.
  static final _skeletonSummary = DashboardSummary(
    todaySales: 12450,
    recentBills: List.generate(
      3,
      (i) => RecentBill(
        id: 'skeleton-$i',
        customerName: 'Customer name',
        amount: 540,
        createdAt: DateTime.now(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final name = context.read<AuthBloc>().state.user?.name ?? '';

    return BlocListener<NavigationCubit, NavigationState>(
      // Only fire when:
      // 1. Home tab (index 0) is the active tab
      // 2. refreshTick actually changed (re-tap happened)
      listenWhen: (prev, curr) =>
          curr.activeTabIndex == 0 && prev.refreshTick != curr.refreshTick,
      listener: (context, _) => _requestLoad(),
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 20,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                name.isEmpty ? 'KhataDost' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          actions: const [ShellActions()],
        ),
        // bottom: false — the shell's floating glass bar overlays the page;
        // the scroll view pads itself past it so content scrolls beneath.
        body: SafeArea(
          bottom: false,
          child: BlocConsumer<DashboardBloc, DashboardState>(
            // Refresh failed but we still have data on screen → toast it.
            listenWhen: (prev, curr) =>
                curr.hasError && curr.summary != null && !prev.hasError,
            listener: (context, state) => AppSnackbar.error(
              context,
              state.errorMessage ?? 'Could not refresh dashboard.',
            ),
            builder: (context, state) {
              // Shimmer on EVERY fetch — first load, tab re-tap, and
              // pull-to-refresh all read as activity (Instagram-style).
              final showSkeleton = state.isLoading;
              final summary = state.summary ?? _skeletonSummary;

              return RefreshIndicator(
                color: AppColors.primary,
                // Pull-to-refresh: same event, independent trigger path.
                onRefresh: () async {
                  _requestLoad();
                  // Wait until loading finishes before dismissing the indicator.
                  await context
                      .read<DashboardBloc>()
                      .stream
                      .firstWhere((s) => !s.isLoading);
                },
                child: state.hasError && state.summary == null
                    ? _FullErrorBody(
                        message: state.errorMessage,
                        onRetry: _requestLoad,
                      )
                    : Skeletonizer(
                        enabled: showSkeleton,
                        effect: const ShimmerEffect(
                          baseColor: AppColors.surfaceVariant,
                          highlightColor: AppColors.cardBg,
                        ),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          // Clears the floating glass bar (extendBody inset).
                          padding: EdgeInsets.fromLTRB(20, 8, 20,
                              MediaQuery.paddingOf(context).bottom + 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Skeleton.shade(
                                child: _TodaysSalesCard(
                                  amount: summary.todaySales,
                                  hidden: _hideAmount,
                                  onToggleHidden: () => setState(
                                    () => _hideAmount = !_hideAmount,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 26),
                              _RecentBillsSection(bills: summary.recentBills),
                            ],
                          ),
                        ),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Today's sales — gradient hero card ──────────────────────────────────────

class _TodaysSalesCard extends StatelessWidget {
  const _TodaysSalesCard({
    required this.amount,
    required this.hidden,
    required this.onToggleHidden,
  });

  final double amount;
  final bool hidden;
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x337C3AED),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Sales",
                  style: TextStyle(
                    color: Colors.white.withOpacity(.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hidden ? '₹ ••••••' : formatInr(amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _todayLabel(DateTime.now()),
                  style: TextStyle(
                    color: Colors.white.withOpacity(.7),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onToggleHidden,
            tooltip: hidden ? 'Show amount' : 'Hide amount',
            icon: Icon(
              hidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.white.withOpacity(.9),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  static String _todayLabel(DateTime now) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return "${now.day} ${months[now.month - 1]} ${now.year}";
  }
}

// ─── Recent bills ────────────────────────────────────────────────────────────

class _RecentBillsSection extends StatelessWidget {
  const _RecentBillsSection({required this.bills});

  final List<RecentBill> bills;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Recent Transactions',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (bills.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 30,
                  color: AppColors.textHint,
                ),
                SizedBox(height: 10),
                Text(
                  'No bills yet today',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Tap the scan button below to make your first bill.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          )
        else
          ...bills.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BillRow(bill: b),
            ),
          ),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill});

  final RecentBill bill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          _InitialsAvatar(name: bill.customerName),
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
                  timeAgo(bill.createdAt),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '+${formatInr(bill.amount)}',
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    String initials = '?';
    if (parts.isNotEmpty) {
      initials = parts.length >= 2
          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
          : parts[0][0].toUpperCase();
    }
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        color: AppColors.primarySurface,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── Full-body load failure ──────────────────────────────────────────────────

class _FullErrorBody extends StatelessWidget {
  const _FullErrorBody({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // ListView so pull-to-refresh keeps working on the error body too.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.errorSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 34,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Could not load your dashboard',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                message ?? 'Please check your connection and try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 22),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Retry'),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Formatting helpers ──────────────────────────────────────────────────────

/// Indian rupee with lakhs/crores commas. ₹3450 → ₹3,450 · ₹123456 → ₹1,23,456
String formatInr(double amount) {
  final n = amount.round();
  final s = n.toString();
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  String head = s.substring(0, s.length - 3);
  head = head.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{2})+$)'),
    (m) => '${m.group(1)},',
  );
  return '₹$head,$last3';
}

/// Short relative time: "just now", "12 minutes ago", "2 hours ago", "3 days ago".
String timeAgo(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h ${h == 1 ? 'hour' : 'hours'} ago';
  }
  final d = diff.inDays;
  return '$d ${d == 1 ? 'day' : 'days'} ago';
}
