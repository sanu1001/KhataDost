import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/navigation_cubit.dart';
import '../../../../core/navigation/navigation_state.dart';
import '../../../../core/shell/shell_actions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_skeletons.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/empty_state.dart';
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
          titleSpacing: 20,
          actions: [
            IconButton(
              icon: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: AppColors.primary,
                  size: 19,
                ),
              ),
              tooltip: 'Add customer',
              onPressed: () =>
                  context.read<NavigationCubit>().pushAddCustomer(),
            ),
            const ShellActions(),
          ],
        ),
        // bottom: false — the shell's floating glass bar overlays the list;
        // the list pads itself past it so content scrolls visibly beneath.
        body: SafeArea(
          bottom: false,
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
                  listener: (context, state) =>
                      AppSnackbar.error(context, state.errorMessage!),
                  builder: (context, state) {
                    switch (state.status) {
                      case CustomersStatus.initial:
                      case CustomersStatus.loading:
                        return const SkeletonTileList();

                      case CustomersStatus.error:
                        return EmptyState.error(
                          message: state.errorMessage,
                          onRetry: _requestLoad,
                        );

                      case CustomersStatus.loaded:
                        if (state.customers.isEmpty) {
                          return EmptyState(
                            icon: Icons.people_outline_rounded,
                            title: 'No customers yet',
                            subtitle:
                                'Add your first customer to start tracking udhaar and payments.',
                            actionLabel: 'Add customer',
                            onAction: () => context
                                .read<NavigationCubit>()
                                .pushAddCustomer(),
                          );
                        }
                        if (state.visibleCustomers.isEmpty) {
                          return const EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matches',
                            subtitle: 'Try a different name or phone number.',
                          );
                        }
                        return ListView.separated(
                          // Clears the floating glass bar (extendBody inset).
                          padding: EdgeInsets.fromLTRB(16, 4, 16,
                              MediaQuery.paddingOf(context).bottom + 12),
                          itemCount: state.visibleCustomers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
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
