import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_skeletons.dart';
import '../../../../customers/domain/entities/customer.dart';
import '../../../../customers/domain/entities/customer_search_index.dart';
import '../../../../customers/presentation/bloc/customers_bloc.dart';
import '../../../../customers/presentation/bloc/customers_event.dart';
import '../../../../customers/presentation/bloc/customers_state.dart';
import '../../bloc/bill_builder_bloc.dart';

/// Settle-screen customer picker. Read-only reuse of the frozen
/// [CustomersBloc] (public API only) with a LOCAL [CustomerSearchIndex] —
/// typing here never touches the Customers tab's own search state.
class CustomerPickSheet extends StatefulWidget {
  const CustomerPickSheet({super.key});

  static Future<void> show(BuildContext context) {
    final customersBloc = context.read<CustomersBloc>();
    final builderBloc = context.read<BillBuilderBloc>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: customersBloc),
          BlocProvider.value(value: builderBloc),
        ],
        child: const CustomerPickSheet(),
      ),
    );
  }

  @override
  State<CustomerPickSheet> createState() => _CustomerPickSheetState();
}

class _CustomerPickSheetState extends State<CustomerPickSheet> {
  String _query = '';

  CustomerSearchIndex? _index;
  List<Customer>? _indexSource;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<CustomersBloc>();
    if (bloc.state.status == CustomersStatus.initial) {
      bloc.add(const CustomersLoadRequested());
    }
  }

  List<Customer> _visible(List<Customer> customers) {
    if (_query.trim().isEmpty) return customers;
    if (!identical(_indexSource, customers)) {
      _index = CustomerSearchIndex.build(customers);
      _indexSource = customers;
    }
    final ids = _index!.query(_query);
    return customers.where((c) => ids.contains(c.id)).toList();
  }

  void _select(BuildContext context, {String? id, String? name}) {
    context
        .read<BillBuilderBloc>()
        .add(SettleCustomerChanged(customerId: id, customerName: name));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                'Select Customer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by name or phone number…',
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 21, color: AppColors.textHint),
                  isDense: true,
                ),
                onChanged: (q) => setState(() => _query = q),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _select(context),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person_off_outlined,
                              size: 20, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Walk-in Customer',
                                  style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                              SizedBox(height: 1),
                              Text('No ledger — pays in full',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textHint),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: BlocBuilder<CustomersBloc, CustomersState>(
                builder: (context, state) {
                  if (state.status == CustomersStatus.loading &&
                      state.customers.isEmpty) {
                    return const SkeletonTileList(count: 5);
                  }
                  if (state.status == CustomersStatus.error &&
                      state.customers.isEmpty) {
                    return const Center(
                      child: Text(
                        'Could not load customers',
                        style: TextStyle(
                            fontSize: 13.5, color: AppColors.textSecondary),
                      ),
                    );
                  }
                  final visible = _visible(state.customers);
                  if (visible.isEmpty) {
                    return const Center(
                      child: Text(
                        'No customers found',
                        style: TextStyle(
                            fontSize: 13.5, color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final c = visible[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: AppColors.cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.divider),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () =>
                                _select(context, id: c.id, name: c.name),
                            child: Padding(
                              padding: const EdgeInsets.all(11),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primarySurface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        c.name.isEmpty
                                            ? '?'
                                            : c.name[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          '+91 ${c.phone}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded,
                                      color: AppColors.textHint),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
