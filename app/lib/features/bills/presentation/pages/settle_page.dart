import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/navigation_cubit.dart';
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill saved')),
        );
        nav.goToBillsAfterSettle();
        billsBloc.add(const BillsLoadRequested());
        builderBloc.add(const BillBuilderReset());
      },
      builder: (context, state) {
        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Settle'),
            leading: BackButton(
              onPressed: () => context.read<NavigationCubit>().goBack(),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Bill summary ────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${state.lines.length} item${state.lines.length == 1 ? '' : 's'}',
                            style:
                                TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        Text(
                          '₹${formatMoney(state.total)}',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Customer ────────────────────────────────────────────
                Text('Customer',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(state.isWalkIn
                        ? Icons.person_off_outlined
                        : Icons.person_outline),
                    title: Text(state.customerName ?? 'Walk-in'),
                    subtitle: state.isWalkIn
                        ? const Text('No ledger — pays in full')
                        : const Text('Shortfall goes on khata'),
                    trailing: state.isWalkIn
                        ? const Icon(Icons.chevron_right)
                        : IconButton(
                            tooltip: 'Back to walk-in',
                            icon: const Icon(Icons.close),
                            onPressed: () => context
                                .read<BillBuilderBloc>()
                                .add(const SettleCustomerChanged()),
                          ),
                    onTap: () => CustomerPickSheet.show(context),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Paying now (the ONE input) ──────────────────────────
                Text('Paying now',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                TextField(
                  controller: _payingController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: _onPayingChanged,
                ),
                const SizedBox(height: 8),
                _SettleHint(state: state),

                // ── Inline server verdict (the 409 lands here) ──────────
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 18, color: scheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                FilledButton(
                  onPressed: state.isSubmitting
                      ? null
                      : () => context
                          .read<BillBuilderBloc>()
                          .add(const BillSubmitted()),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save bill',
                          style: TextStyle(fontSize: 16)),
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
    final scheme = Theme.of(context).colorScheme;
    final delta = state.creditDelta; // total − paying

    final String text;
    if (state.isWalkIn) {
      text = delta == 0
          ? 'Walk-in — paid in full.'
          : 'Walk-in must pay the full ₹${formatMoney(state.total)} (pick a customer to allow credit).';
    } else if (delta > 0) {
      text =
          '₹${formatMoney(delta)} goes on ${state.customerName}\'s khata.';
    } else if (delta < 0) {
      text =
          '₹${formatMoney(-delta)} extra — pays down ${state.customerName}\'s old dues.';
    } else {
      text = 'Fully paid — nothing goes on khata.';
    }

    return Text(
      text,
      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
    );
  }
}
