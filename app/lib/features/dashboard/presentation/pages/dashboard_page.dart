import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/bloc/auth_bloc.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';

/// Home screen after login.
/// Three sections: greeting, today's sales, recent bills.
/// Skeleton placeholders on all three while `status == loading`.
///
/// NOTE: Refetch on tab focus will be wired in when the bottom-nav shell
/// (StatefulShellRoute) is built. For now [initState] is the only trigger.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(const DashboardLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final shopName =
        context.read<AuthBloc>().state.user?.shopName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('KhataDost'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // Wired up by the Settings feature.
            },
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GreetingSection(
                    shopName: shopName,
                    isLoading: state.isLoading && state.summary == null,
                  ),
                  const SizedBox(height: 24),
                  _TodaysSalesCard(
                    amount: state.summary?.todaySales,
                    isLoading: state.isLoading,
                  ),
                  const SizedBox(height: 28),
                  _RecentBillsSection(
                    bills: state.summary?.recentBills ?? const [],
                    isLoading: state.isLoading,
                  ),
                  if (state.hasError) ...[
                    const SizedBox(height: 20),
                    _ErrorBanner(
                      message: state.errorMessage ?? 'Failed to load.',
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Section 1: Greeting ─────────────────────────────────────────────────────

class _GreetingSection extends StatelessWidget {
  const _GreetingSection({
    required this.shopName,
    required this.isLoading,
  });

  final String shopName;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _Skeleton(width: 220, height: 28),
          SizedBox(height: 8),
          _Skeleton(width: 140, height: 14),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greetingFor(DateTime.now(), shopName),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _todayLabel(DateTime.now()),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static String _greetingFor(DateTime now, String shopName) {
    final hour = now.hour;
    final part = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return shopName.isEmpty ? part : '$part, $shopName';
  }

  static String _todayLabel(DateTime now) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

// ─── Section 2: Today's sales ────────────────────────────────────────────────

class _TodaysSalesCard extends StatelessWidget {
  const _TodaysSalesCard({required this.amount, required this.isLoading});

  final double? amount;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Sales",
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.onPrimaryContainer.withOpacity(0.8),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const _Skeleton(width: 180, height: 36)
          else
            Text(
              _formatInr(amount ?? 0),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Section 3: Recent bills ─────────────────────────────────────────────────

class _RecentBillsSection extends StatelessWidget {
  const _RecentBillsSection({required this.bills, required this.isLoading});

  final List<RecentBill> bills;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Recent bills',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (isLoading)
          Column(
            children: List.generate(
              3,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: _BillRowSkeleton(),
              ),
            ),
          )
        else if (bills.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 4),
            child: Text(
              'No bills yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.customerName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _timeAgo(bill.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatInr(bill.amount),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillRowSkeleton extends StatelessWidget {
  const _BillRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Skeleton(width: 120, height: 16),
                SizedBox(height: 8),
                _Skeleton(width: 70, height: 12),
              ],
            ),
          ),
          SizedBox(width: 12),
          _Skeleton(width: 64, height: 18),
        ],
      ),
    );
  }
}

// ─── Skeleton primitive ──────────────────────────────────────────────────────
// Lightweight stand-in for Skeletonizer (which is not in pubspec yet).
// Swap this widget out once `skeletonizer` is added — the rest of the page
// already structures content for an easy upgrade.

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

// ─── Error banner ────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Formatting helpers ──────────────────────────────────────────────────────

/// Indian rupee with lakhs/crores commas. ₹3450 → ₹3,450 · ₹123456 → ₹1,23,456
String _formatInr(double amount) {
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
String _timeAgo(DateTime t) {
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
