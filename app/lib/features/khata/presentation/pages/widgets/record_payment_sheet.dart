import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../bills/presentation/pages/widgets/formats.dart';
import '../../../../customers/presentation/bloc/customers_bloc.dart';
import '../../../../customers/presentation/bloc/customers_event.dart';
import '../../bloc/khata_bloc.dart';

/// The ONE balance-down action (§12): enter an amount → a `payment`
/// entry is written → the bloc re-fetches and the balance recomputes.
/// Balance is never typed — only moved by entries.
///
/// Server 400s (and the identical client preflight) surface INLINE here,
/// settle-page style. On success: snackbar, pop, and a
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
        final customersBloc = context.read<CustomersBloc>();

        // Snackbar attaches to the root messenger, so it survives the pop.
        AppSnackbar.success(context, 'Payment recorded');
        Navigator.of(context).pop();
        // has_dues is computed from this ledger server-side — refresh the
        // frozen customers list so the tab flips without a re-tap.
        customersBloc.add(const CustomersLoadRequested());
      },
      builder: (context, state) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.successSurface,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.payments_outlined,
                          color: AppColors.success, size: 21),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Text(
                        'Receive Payment',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Current balance: ₹${formatMoney(state.balance)} — a payment entry brings it down.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  autofocus: true,
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
                    hintText: '0.00',
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
                            state.paymentError!,
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

                const SizedBox(height: 18),
                FilledButton(
                  onPressed: state.isSubmittingPayment
                      ? null
                      : () => _submit(context),
                  child: state.isSubmittingPayment
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save payment'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
