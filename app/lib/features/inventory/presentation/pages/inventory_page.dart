import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/navigation/navigation_cubit.dart';
import '../../../../core/shell/shell_actions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';

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
                Icons.add_rounded,
                color: AppColors.primary,
                size: 21,
              ),
            ),
            tooltip: 'Add item',
            onPressed: () => context.read<NavigationCubit>().pushAddItem(),
          ),
          const ShellActions(),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
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
      return EmptyState.error(
        message: state.errorMessage,
        onRetry: () =>
            context.read<InventoryBloc>().add(const InventoryLoadRequested()),
      );
    }

    final isLoading = state.status == InventoryStatus.loading;

    if (!isLoading && state.items.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No items yet',
        subtitle: 'Add your first item to start building your price book.',
        actionLabel: 'Add item',
        onAction: () => context.read<NavigationCubit>().pushAddItem(),
      );
    }

    if (!isLoading && state.visibleItems.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        subtitle: 'Try a different name.',
      );
    }

    final items = isLoading ? kInventorySkeletonItems : state.visibleItems;

    return Skeletonizer(
      enabled: isLoading,
      effect: const ShimmerEffect(
        baseColor: AppColors.surfaceVariant,
        highlightColor: AppColors.cardBg,
      ),
      child: ListView.separated(
        // Bottom inset = floating glass bar height (injected by the shell's
        // extendBody) + breathing room, so the last item scrolls clear of
        // the bar while the list stays visible beneath the glass.
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, MediaQuery.paddingOf(context).bottom + 12),
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
