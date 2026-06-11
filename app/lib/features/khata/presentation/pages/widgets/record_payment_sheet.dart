import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../bills/presentation/pages/widgets/formats.dart';
import '../../../../customers/presentation/bloc/customers_bloc.dart';
import '../../../../customers/presentation/bloc/customers_event.dart';
import '../../bloc/khata_bloc.dart';

/// The ONE balance-down action (§12): enter an amount → a `payment`
/// entry is written → the bloc re-fetches and the balance recomputes.
/// Balance is never typed — only moved by entries.
///
/// Server 400s (and the identical client preflight) surface INLINE here,
/// settle-page style. On success: pop, snackbar, and a
/// [CustomersLoadRequested] dispatch to the frozen CustomersBloc
/// (public-API reuse) so the Customers tab's has_dues flips immediately.
class RecordPaymentSheet extends StatefulWidget {
  const RecordPaymentSheet({super.key});

  static Future<void> show(BuildContext context) {
    final khataBloc = context.read<KhataBloc>();
    final customersBloc = context.read<CustomersBloc>();
    khataBloc.add(const KhataPaymentReset()); // clear stale sheet state
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: khataBloc),
          BlocProvider.value(value: customersBloc),
        ],
        child: const RecordPaymentSheet(),
      ),
    );
  }

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  final TextEditingController _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    context
        .read<KhataBloc>()
        .add(KhataPaymentSubmitted(double.tryParse(_amountController.text)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KhataBloc, KhataState>(
      listenWhen: (prev, curr) =>
          prev.paymentStatus != curr.paymentStatus &&
          curr.paymentStatus == KhataPaymentStatus.success,
      listener: (context, state) {
        // Grab refs BEFORE popping — this widget is about to dispose.
        final messenger = ScaffoldMessenger.of(context);
        final customersBloc = context.read<CustomersBloc>();

        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Payment recorded')),
        );
        // has_dues is computed from this ledger server-side — refresh the
        // frozen customers list so the tab flips without a re-tap.
        customersBloc.add(const CustomersLoadRequested());
      },
      builder: (context, state) {
        final scheme = Theme.of(context).colorScheme;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Record Payment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current balance: ₹${formatMoney(state.balance)} — a payment entry brings it down.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    hintText: '0.00',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) {
                    if (!state.isSubmittingPayment) _submit(context);
                  },
                ),

                // ── Inline verdict (preflight or the server's 400) ──────
                if (state.paymentStatus == KhataPaymentStatus.error &&
                    state.paymentError != null) ...[
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
                            state.paymentError!,
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                FilledButton(
                  onPressed: state.isSubmittingPayment
                      ? null
                      : () => _submit(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: state.isSubmittingPayment
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save payment',
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
