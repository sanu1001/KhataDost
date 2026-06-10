import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/item.dart';

class ItemListTile extends StatelessWidget {
  final Item item;
  final VoidCallback? onTap;

  const ItemListTile({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias, // so the InkWell ripple respects the radius
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _IconChip(item: item),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        )),
                    const SizedBox(height: 3),
                    Text(_priceHint(item),
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }

  // Exhaustive switch on the sealed Item — compiler forces both types handled.
  String _priceHint(Item item) => switch (item) {
    UnitItem(:final variants) => _unitHint(variants),
    LooseItem(:final rate, :final unit) => '₹${_money(rate)}/$unit',
  };

  // String _unitHint(List<ItemVariant> variants) {
  //   if (variants.isEmpty) return '—';
  //   final base =
  //   variants.firstWhere((v) => v.isDefault, orElse: () => variants.first);
  //   final count = variants.length > 1 ? ' · ${variants.length} sizes' : '';
  //   return 'from ₹${_money(base.price)}$count';
  // }

  String _unitHint(List<ItemVariant> variants) {
    if (variants.isEmpty) return '—';
    final defaults = variants.where((v) => v.isDefault);
    final base = defaults.isEmpty ? variants.first : defaults.first;
    final count = variants.length > 1 ? ' · ${variants.length} sizes' : '';
    return 'from ₹${_money(base.price)}$count';
  }

  String _money(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

class _IconChip extends StatelessWidget {
  final Item item;
  const _IconChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final icon = switch (item) {
      UnitItem() => Icons.shopping_bag_outlined,
      LooseItem() => Icons.scale_outlined,
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.10), // soft green tint
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 22, color: AppColors.primary),
    );
  }
}