import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/navigation_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
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
      listener: (context, _) {
        AppSnackbar.success(context, 'Customer deleted');
        context.read<NavigationCubit>().goBack();
      },
      child: BlocBuilder<CustomersBloc, CustomersState>(
        builder: (context, state) {
          final customer =
              state.customers.firstWhereOrNull((c) => c.id == customerId);

          // Guard: not in state yet (deep-link or load still in progress).
          if (customer == null) {
            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.read<NavigationCubit>().goBack(),
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
                  icon: const Icon(Icons.edit_outlined, size: 22),
                  tooltip: 'Edit customer',
                  onPressed: () => context
                      .read<NavigationCubit>()
                      .pushCustomerEdit(customerId),
                ),
                // Delete only rendered when has_dues == false.
                // Defense layer 1: client hides it.
                // Defense layer 2: server rejects it with 409 (step 11).
                if (!customer.hasDues)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 22,
                      color: AppColors.error,
                    ),
                    tooltip: 'Delete customer',
                    onPressed: () async {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: 'Delete customer?',
                        message:
                            '"${customer.name}" and their details will be removed. This cannot be undone.',
                        confirmLabel: 'Delete',
                        destructive: true,
                      );
                      if (confirmed && context.mounted) {
                        context
                            .read<CustomersBloc>()
                            .add(CustomerDeleted(customerId));
                      }
                    },
                  ),
              ],
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Identity card ───────────────────────────────────
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Name',
                            value: customer.name,
                          ),
                          const Divider(height: 22),
                          _DetailRow(
                            icon: Icons.phone_outlined,
                            label: 'Phone',
                            value: '+91 ${customer.phone}',
                          ),
                          if (customer.email != null) ...[
                            const Divider(height: 22),
                            _DetailRow(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: customer.email!,
                            ),
                          ],
                          if (customer.notes != null) ...[
                            const Divider(height: 22),
                            _DetailRow(
                              icon: Icons.notes_rounded,
                              label: 'Notes',
                              value: customer.notes!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Phase 5 (sanctioned): the designed "becomes the Khata home"
                  // stub grows its entry point — detail page → khata page.
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.menu_book_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      title: const Text('Khata',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      subtitle: const Text('Balance & entry timeline',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary)),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textHint),
                      onTap: () =>
                          context.read<NavigationCubit>().pushKhata(customerId),
                    ),
                  ),

                  if (customer.hasDues) ...[
                    const SizedBox(height: 14),
                    const _DuesBanner(),
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
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppColors.textHint),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DuesBanner extends StatelessWidget {
  const _DuesBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFFDE4C8)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 17, color: AppColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cannot delete — customer has outstanding dues',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
