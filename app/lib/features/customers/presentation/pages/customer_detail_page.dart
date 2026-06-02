import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/navigation_cubit.dart';
import '../bloc/customers_bloc.dart';
import '../bloc/customers_event.dart';
import '../bloc/customers_state.dart';

class CustomerDetailPage extends StatelessWidget {
  final String customerId;

  const CustomerDetailPage({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return BlocListener<CustomersBloc, CustomersState>(
      // When the customer vanishes from the list (deleted), pop back.
      listenWhen: (prev, curr) =>
      curr.status == CustomersStatus.loaded &&
          prev.customers.any((c) => c.id == customerId) &&
          !curr.customers.any((c) => c.id == customerId),
      listener: (context, _) => context.read<NavigationCubit>().goBack(),
      child: BlocBuilder<CustomersBloc, CustomersState>(
        builder: (context, state) {
          final customer = state.customers
              .firstWhereOrNull((c) => c.id == customerId);

          // Guard: not in state yet (deep-link or load still in progress).
          if (customer == null) {
            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () =>
                      context.read<NavigationCubit>().goBack(),
                ),
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(customer.name),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.read<NavigationCubit>().goBack(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context
                      .read<NavigationCubit>()
                      .pushCustomerEdit(customerId),
                ),
                // Delete only rendered when has_dues == false.
                // Defense layer 1: client hides it.
                // Defense layer 2: server rejects it with 409 (step 11).
                if (!customer.hasDues)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () => context
                        .read<CustomersBloc>()
                        .add(CustomerDeleted(customerId)),
                  ),
              ],
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _DetailRow(label: 'Name', value: customer.name),
                  _DetailRow(label: 'Phone', value: customer.phone),
                  if (customer.email != null)
                    _DetailRow(label: 'Email', value: customer.email!),
                  if (customer.notes != null)
                    _DetailRow(label: 'Notes', value: customer.notes!),
                  if (customer.hasDues) ...[
                    const SizedBox(height: 16),
                    _DuesBanner(),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _DuesBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cannot delete — customer has outstanding dues',
              style: TextStyle(fontSize: 13, color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}