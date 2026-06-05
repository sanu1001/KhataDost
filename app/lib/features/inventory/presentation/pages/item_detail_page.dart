import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/navigation_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/item.dart';
import '../bloc/inventory_bloc.dart';

class ItemDetailPage extends StatelessWidget {
  final String itemId;
  const ItemDetailPage({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryBloc, InventoryState>(
      builder: (context, state) {
        final matches = state.items.where((i) => i.id == itemId);
        if (matches.isEmpty) {
          // Item was deleted — loading indicator until the BLoC
          // finishes re-fetching and we pop from the listener above.
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _DetailView(item: matches.first);
      },
    );
  }
}

class _DetailView extends StatelessWidget {
  final Item item;
  const _DetailView({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        leading: BackButton(
          onPressed: () => context.read<NavigationCubit>().goBack(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit item',
            onPressed: () =>
                context.read<NavigationCubit>().pushItemEdit(item.id),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TypeBadge(item: item),
          const SizedBox(height: 16),

          // Exhaustive sealed switch — compiler forces both types handled.
          switch (item) {
            UnitItem(:final variants) => _VariantSection(
              itemId: item.id,
              variants: variants,
            ),
            LooseItem(:final rate, :final unit) => _LooseSection(
              rate: rate,
              unit: unit,
            ),
          },

          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            label: const Text('Delete item',
                style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text(
            'Remove "${item.name}" from your price book. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        context.read<InventoryBloc>().add(ItemDeleted(item.id));
        context.read<NavigationCubit>().goBack();
      }
    });
  }
}

// ── Type badge ────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final Item item;
  const _TypeBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    final isUnit = item is UnitItem;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUnit ? Icons.shopping_bag_outlined : Icons.scale_outlined,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            isUnit ? 'Unit / Packaged' : 'Loose / By weight',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Unit item variant list ─────────────────────────────────────────────────

class _VariantSection extends StatelessWidget {
  final String itemId;
  final List<ItemVariant> variants;
  const _VariantSection({required this.itemId, required this.variants});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Text('Variants',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    )),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showAddDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (variants.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No variants yet.',
                  style:
                  TextStyle(fontSize: 13.5, color: AppColors.textHint)),
            )
          else
            ...variants.map((v) => _VariantTile(itemId: itemId, variant: v)),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final labelCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (dlg) => AlertDialog(
        title: const Text('Add variant'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: labelCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Label', hintText: 'e.g. 500ml'),
                validator: (v) =>
                v?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price ₹'),
                validator: (v) {
                  if (v?.trim().isEmpty ?? true) return 'Required';
                  if (double.tryParse(v!) == null) return 'Invalid price';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlg),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dlg);
                context.read<InventoryBloc>().add(VariantAdded(
                  itemId: itemId,
                  label: labelCtrl.text.trim(),
                  price: double.parse(priceCtrl.text.trim()),
                  isDefault: false,
                ));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _VariantTile extends StatelessWidget {
  final String itemId;
  final ItemVariant variant;
  const _VariantTile({required this.itemId, required this.variant});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        variant.isDefault ? Icons.star_rounded : Icons.star_outline_rounded,
        size: 18,
        color: variant.isDefault ? AppColors.accent : AppColors.textHint,
      ),
      title: Text(variant.label,
          style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('₹${_fmt(variant.price)}',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: AppColors.textSecondary),
            onPressed: () => _showEditDialog(context),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.error),
            onPressed: () => context.read<InventoryBloc>().add(
                VariantDeleted(itemId: itemId, variantId: variant.id)),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final labelCtrl = TextEditingController(text: variant.label);
    final priceCtrl = TextEditingController(text: _fmt(variant.price));
    var isDefault = variant.isDefault;
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (dlg) => StatefulBuilder(
        builder: (_, setDlgState) => AlertDialog(
          title: const Text('Edit variant'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Label'),
                  validator: (v) =>
                  v?.trim().isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: priceCtrl,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price ₹'),
                  validator: (v) {
                    if (v?.trim().isEmpty ?? true) return 'Required';
                    if (double.tryParse(v!) == null) return 'Invalid';
                    return null;
                  },
                ),
                const SizedBox(height: 4),
                CheckboxListTile(
                  value: isDefault,
                  onChanged: (v) =>
                      setDlgState(() => isDefault = v ?? false),
                  title: const Text('Set as default',
                      style: TextStyle(fontSize: 14)),
                  activeColor: AppColors.primary,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dlg),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dlg);
                  context.read<InventoryBloc>().add(VariantUpdated(
                    itemId: itemId,
                    variantId: variant.id,
                    label: labelCtrl.text.trim(),
                    price: double.parse(priceCtrl.text.trim()),
                    isDefault: isDefault,
                  ));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

// ── Loose item display ─────────────────────────────────────────────────────

class _LooseSection extends StatelessWidget {
  final double rate;
  final String unit;
  const _LooseSection({required this.rate, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rate per unit',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text('₹${_fmt(rate)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(unit,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}