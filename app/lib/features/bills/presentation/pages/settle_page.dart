import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/navigation_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../bloc/bill_builder_bloc.dart';
import '../bloc/bills_bloc.dart';
import 'widgets/customer_pick_sheet.dart';
import 'widgets/formats.dart';

/// Settle (§12): pick customer or walk-in, ONE input — "paying now",
/// pre-filled to the bill total (cash sale = one tap). The credit/payment
/// split is COMPUTED, never asked. The server is the authority: its 409
/// (walk-in must pay full) and 400s surface INLINE here, not as toasts.
class SettlePage extends StatefulWidget {
  const SettlePage({super.key});

  @override
  State<SettlePage> createState() => _SettlePageState();
}

class _SettlePageState extends State<SettlePage> {
  late final TextEditingController _payingController;

  @override
  void initState() {
    super.initState();
    final state = context.read<BillBuilderBloc>().state;
    _payingController = TextEditingController(
      text: formatMoney(state.effectivePayingNow),
    );
  }

  @override
  void dispose() {
    _payingController.dispose();
    super.dispose();
  }

  void _onPayingChanged(String text) {
    final bloc = context.read<BillBuilderBloc>();
    if (text.trim().isEmpty) {
      bloc.add(const PayingNowChanged(null)); // cleared → back to default
      return;
    }
    final v = double.tryParse(text);
    if (v != null && v >= 0) bloc.add(PayingNowChanged(v));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BillBuilderBloc, BillBuilderState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status &&
          curr.status == BillBuilderStatus.success,
      listener: (context, state) {
        // Grab refs BEFORE navigating — this widget is about to dispose.
        final billsBloc = context.read<BillsBloc>();
        final builderBloc = context.read<BillBuilderBloc>();
        final nav = context.read<NavigationCubit>();

        AppSnackbar.success(context, 'Bill saved');
        nav.goToBillsAfterSettle();
        billsBloc.add(const BillsLoadRequested());
        builderBloc.add(const BillBuilderReset());
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Bill Summary'),
            leading: BackButton(
              onPressed: () => context.read<NavigationCubit>().goBack(),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Bill summary ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.gradientStart,
                        AppColors.gradientEnd,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${state.lines.length} item${state.lines.length == 1 ? '' : 's'} on this bill',
                              style: TextStyle(
                                color: Colors.white.withOpacity(.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹ ${formatMoney(state.total)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.receipt_long_rounded,
                          color: Colors.white, size: 34),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Customer ────────────────────────────────────────────
                const Text('Customer',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Material(
                  color: AppColors.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.divider),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => CustomerPickSheet.show(context),
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: state.isWalkIn
                                  ? AppColors.surfaceVariant
                                  : AppColors.primarySurface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              state.isWalkIn
                                  ? Icons.person_off_outlined
                                  : Icons.person_outline_rounded,
                              size: 21,
                              color: state.isWalkIn
                                  ? AppColors.textSecondary
                                  : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.customerName ?? 'Walk-in',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  state.isWalkIn
                                      ? 'No ledger — pays in full'
                                      : 'Shortfall goes on khata',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (state.isWalkIn)
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.textHint)
                          else
                            IconButton(
                              tooltip: 'Back to walk-in',
                              icon: const Icon(Icons.close_rounded,
                                  size: 20, color: AppColors.textSecondary),
                              onPressed: () => context
                                  .read<BillBuilderBloc>()
                                  .add(const SettleCustomerChanged()),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Paying now (the ONE input) ──────────────────────────
                const Text('Paying now',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _payingController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary),
                  ),
                  onChanged: _onPayingChanged,
                ),
                const SizedBox(height: 10),
                _SettleHint(state: state),

                // ── Inline server verdict (the 409 lands here) ──────────
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.errorSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_rounded,
                            size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 26),
                FilledButton(
                  onPressed: state.isSubmitting
                      ? null
                      : () => context
                          .read<BillBuilderBloc>()
                          .add(const BillSubmitted()),
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirm & Save'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// What the entered amount will DO — the computed split, in words.
class _SettleHint extends StatelessWidget {
  const _SettleHint({required this.state});

  final BillBuilderState state;

  @override
  Widget build(BuildContext context) {
    final delta = state.creditDelta; // total − paying

    final String text;
    final IconData icon;
    final Color color;
    final Color bg;
    if (state.isWalkIn) {
      if (delta == 0) {
        text = 'Walk-in — paid in full.';
        icon = Icons.check_circle_rounded;
        color = AppColors.success;
        bg = AppColors.successSurface;
      } else {
        text =
            'Walk-in must pay the full ₹${formatMoney(state.total)} (pick a customer to allow credit).';
        icon = Icons.info_rounded;
        color = AppColors.warning;
        bg = AppColors.warningSurface;
      }
    } else if (delta > 0) {
      text = '₹${formatMoney(delta)} goes on ${state.customerName}\'s khata.';
      icon = Icons.menu_book_rounded;
      color = AppColors.warning;
      bg = AppColors.warningSurface;
    } else if (delta < 0) {
      text =
          '₹${formatMoney(-delta)} extra — pays down ${state.customerName}\'s old dues.';
      icon = Icons.trending_down_rounded;
      color = AppColors.success;
      bg = AppColors.successSurface;
    } else {
      text = 'Fully paid — nothing goes on khata.';
      icon = Icons.check_circle_rounded;
      color = AppColors.success;
      bg = AppColors.successSurface;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
