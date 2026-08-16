import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_skeletons.dart';
import '../../../../inventory/domain/entities/item.dart';
import '../../../../inventory/domain/entities/item_search_index.dart';
import '../../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../domain/entities/draft_line.dart';
import '../../bloc/bill_builder_bloc.dart';
import 'formats.dart';

/// Manual on-ramp: search THIS user's inventory, tap to drop a card on
/// the bill.
///
/// Read-only reuse of the frozen [InventoryBloc] (public API only) — and
/// the search is a LOCAL [ItemSearchIndex] over its items, so typing here
/// can never disturb the Inventory tab's own visible list.
class ItemPickSheet extends StatefulWidget {
  const ItemPickSheet({super.key});

  /// Bottom-sheet builders get the ROOT navigator context — the route's
  /// providers are not visible there. Re-provide the blocs explicitly.
  static Future<void> show(BuildContext context) {
    final inventoryBloc = context.read<InventoryBloc>();
    final builderBloc = context.read<BillBuilderBloc>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: inventoryBloc),
          BlocProvider.value(value: builderBloc),
        ],
        child: const ItemPickSheet(),
      ),
    );
  }

  @override
  State<ItemPickSheet> createState() => _ItemPickSheetState();
}

class _ItemPickSheetState extends State<ItemPickSheet> {
  String _query = '';

  // Local index, memoized by list identity (bloc emits a new list on
  // change, so identical() is a correct cache key).
  ItemSearchIndex? _index;
  List<Item>? _indexSource;

  @override
  void initState() {
    super.initState();
    // FAB path may arrive before the Inventory tab ever loaded.
    final bloc = context.read<InventoryBloc>();
    if (bloc.state.status == InventoryStatus.initial) {
      bloc.add(const InventoryLoadRequested());
    }
  }

  List<Item> _visible(List<Item> items) {
    if (_query.trim().isEmpty) return items;
    if (!identical(_indexSource, items)) {
      _index = ItemSearchIndex.build(items);
      _indexSource = items;
    }
    final ids = _index!.query(_query);
    return items.where((i) => ids.contains(i.id)).toList();
  }

  String _subtitle(Item item) {
    switch (item) {
      case UnitItem():
        if (item.variants.isEmpty) return 'no variants';
        // defaultVariantOf, not firstWhere(orElse:) — see its doc for the
        // List<ItemVariantModel> covariance TypeError this avoids.
        final d = defaultVariantOf(item);
        final n = item.variants.length;
        return '₹${formatMoney(d.price)} · $n variant${n == 1 ? '' : 's'}';
      case LooseItem():
        return '₹${formatMoney(item.rate)} / ${item.unit} · loose';
    }
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
                'Add from Inventory',
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
                  hintText: 'Search inventory…',
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 21, color: AppColors.textHint),
                  isDense: true,
                ),
                onChanged: (q) => setState(() => _query = q),
              ),
            ),
            Expanded(
              child: BlocBuilder<InventoryBloc, InventoryState>(
                builder: (context, state) {
                  if (state.status == InventoryStatus.loading &&
                      state.items.isEmpty) {
                    return const SkeletonTileList(count: 5);
                  }
                  if (state.status == InventoryStatus.error &&
                      state.items.isEmpty) {
                    return const Center(
                      child: Text(
                        'Could not load inventory',
                        style: TextStyle(
                            fontSize: 13.5, color: AppColors.textSecondary),
                      ),
                    );
                  }
                  final visible = _visible(state.items);
                  if (visible.isEmpty) {
                    return const Center(
                      child: Text(
                        'No items — add it as Misc instead',
                        style: TextStyle(
                            fontSize: 13.5, color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final item = visible[i];
                      final isLoose = item is LooseItem;
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
                            onTap: () {
                              context
                                  .read<BillBuilderBloc>()
                                  .add(ItemPicked(item));
                              Navigator.of(context).pop();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(11),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySurface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isLoose
                                          ? Icons.scale_outlined
                                          : Icons.shopping_bag_outlined,
                                      size: 20,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
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
                                          _subtitle(item),
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySurface,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: const Icon(Icons.add_rounded,
                                        size: 18, color: AppColors.primary),
                                  ),
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
