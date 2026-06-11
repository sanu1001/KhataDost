import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
                  hintText: 'Search inventory…',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (q) => setState(() => _query = q),
              ),
            ),
            Expanded(
              child: BlocBuilder<InventoryBloc, InventoryState>(
                builder: (context, state) {
                  if (state.status == InventoryStatus.loading &&
                      state.items.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == InventoryStatus.error &&
                      state.items.isEmpty) {
                    return const Center(
                        child: Text('Could not load inventory'));
                  }
                  final visible = _visible(state.items);
                  if (visible.isEmpty) {
                    return const Center(
                        child: Text('No items — add it as Misc instead'));
                  }
                  return ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final item = visible[i];
                      return ListTile(
                        leading: Icon(item is LooseItem
                            ? Icons.scale_outlined
                            : Icons.inventory_2_outlined),
                        title: Text(item.name),
                        subtitle: Text(_subtitle(item)),
                        onTap: () {
                          context
                              .read<BillBuilderBloc>()
                              .add(ItemPicked(item));
                          Navigator.of(context).pop();
                        },
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
