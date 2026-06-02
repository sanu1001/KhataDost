import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/navigation_cubit.dart';
import '../../../../core/navigation/navigation_state.dart';
import '../../../../core/shell/shell_actions.dart';
import '../bloc/customers_bloc.dart';
import '../bloc/customers_event.dart';
import '../bloc/customers_state.dart';
import 'widgets/customer_search_bar.dart';
import 'widgets/customer_list_tile.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  // Customers is branch index 3 in the shell.
  static const int _branchIndex = 3;

  void _requestLoad() {
    context.read<CustomersBloc>().add(const CustomersLoadRequested());
  }

  @override
  void initState() {
    super.initState();
    _requestLoad();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationCubit, NavigationState>(
      // Refetch only when:
      // 1. Customers tab (index 3) is the active tab
      // 2. refreshTick changed (the user re-tapped the tab they're on)
      listenWhen: (prev, curr) =>
      curr.activeTabIndex == _branchIndex &&
          prev.refreshTick != curr.refreshTick,
      listener: (context, _) => _requestLoad(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Customers'),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              onPressed: () =>
                  context.read<NavigationCubit>().pushAddCustomer(),
            ),
            const ShellActions(),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              CustomerSearchBar(
                onChanged: (query) => context
                    .read<CustomersBloc>()
                    .add(CustomerSearchChanged(query)),
              ),
              Expanded(
                child: BlocConsumer<CustomersBloc, CustomersState>(
                  // Snackbar for MUTATION errors only (status stays loaded).
                  listenWhen: (prev, curr) =>
                  curr.status == CustomersStatus.loaded &&
                      curr.errorMessage != null &&
                      curr.errorMessage != prev.errorMessage,
                  listener: (context, state) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.errorMessage!)),
                    );
                  },
                  builder: (context, state) {
                    switch (state.status) {
                      case CustomersStatus.initial:
                      case CustomersStatus.loading:
                        return const Center(
                          child: CircularProgressIndicator(),
                        );

                      case CustomersStatus.error:
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                state.errorMessage ?? 'Something went wrong',
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _requestLoad,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );

                      case CustomersStatus.loaded:
                        if (state.customers.isEmpty) {
                          return const Center(
                            child: Text('No customers yet'),
                          );
                        }
                        if (state.visibleCustomers.isEmpty) {
                          return const Center(child: Text('No matches'));
                        }
                        return ListView.builder(
                          itemCount: state.visibleCustomers.length,
                          itemBuilder: (context, i) {
                            final customer = state.visibleCustomers[i];
                            return CustomerListTile(
                              customer: customer,
                              onTap: () => context
                                  .read<NavigationCubit>()
                                  .pushCustomerDetail(customer.id),
                            );
                          },
                        );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}