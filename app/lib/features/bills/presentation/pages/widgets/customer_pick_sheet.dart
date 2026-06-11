import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search customers…',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (q) => setState(() => _query = q),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_off_outlined),
              title: const Text('Walk-in'),
              subtitle: const Text('No ledger — pays in full'),
              onTap: () => _select(context),
            ),
            const Divider(height: 1),
            Expanded(
              child: BlocBuilder<CustomersBloc, CustomersState>(
                builder: (context, state) {
                  if (state.status == CustomersStatus.loading &&
                      state.customers.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == CustomersStatus.error &&
                      state.customers.isEmpty) {
                    return const Center(
                        child: Text('Could not load customers'));
                  }
                  final visible = _visible(state.customers);
                  if (visible.isEmpty) {
                    return const Center(child: Text('No customers found'));
                  }
                  return ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final c = visible[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                              c.name.isEmpty ? '?' : c.name[0].toUpperCase()),
                        ),
                        title: Text(c.name),
                        subtitle: Text(c.phone),
                        onTap: () => _select(context, id: c.id, name: c.name),
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
