import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/navigation/navigation_cubit.dart';
import '../../../../core/shell/shell_actions.dart';
import '../../../../core/theme/app_theme.dart';

import '../bloc/inventory_bloc.dart';
import 'widgets/inventory_skeletons.dart';
import 'widgets/item_list_tile.dart';
import 'widgets/item_search_bar.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  @override
  void initState() {
    super.initState();
    final bloc = context.read<InventoryBloc>();
    if (bloc.state.status == InventoryStatus.initial) {
      bloc.add(const InventoryLoadRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    // backgroundColor + appBar styling inherited from AppTheme.light
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            tooltip: 'Add item',
            onPressed: () => context.read<NavigationCubit>().pushAddItem(),
          ),
          const ShellActions(),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ItemSearchBar(),
          ),
          Expanded(
            child: BlocBuilder<InventoryBloc, InventoryState>(
              builder: (context, state) => _InventoryBody(state: state),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryBody extends StatelessWidget {
  final InventoryState state;
  const _InventoryBody({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.status == InventoryStatus.error && state.items.isEmpty) {
      return _ErrorState(
        message: state.errorMessage ?? 'Something went wrong',
        onRetry: () =>
            context.read<InventoryBloc>().add(const InventoryLoadRequested()),
      );
    }

    final isLoading = state.status == InventoryStatus.loading;

    if (!isLoading && state.items.isEmpty) {
      return const _EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No items yet',
        subtitle: 'Add your first item to start building your price book.',
      );
    }

    if (!isLoading && state.visibleItems.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off,
        title: 'No matches',
        subtitle: 'Try a different name.',
      );
    }

    final items = isLoading ? kInventorySkeletonItems : state.visibleItems;

    return Skeletonizer(
      enabled: isLoading,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final item = items[i];
          return ItemListTile(
            item: item,
            onTap: isLoading
                ? null
                : () => context.read<NavigationCubit>().pushItemDetail(item.id),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppColors.primary), // was hardcoded
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14.5, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            // Inherits green bg + radius 12 from elevatedButtonTheme;
            // we only shrink it from full-width to a compact size.
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(140, 48)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}