import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// One variant input row in the add-item form.
/// The parent form manages all controllers and isDefault state.
class VariantRow extends StatelessWidget {
  final int index;
  final TextEditingController labelController;
  final TextEditingController priceController;
  final bool isDefault;
  final VoidCallback onSetDefault;
  final VoidCallback? onRemove; // null when this is the last row

  const VariantRow({
    super.key,
    required this.index,
    required this.labelController,
    required this.priceController,
    required this.isDefault,
    required this.onSetDefault,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault ? AppColors.primary : AppColors.divider,
          width: isDefault ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: TextFormField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    hintText: 'e.g. small',
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Price ₹',
                    hintText: '0',
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid';
                    return null;
                  },
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      size: 20, color: AppColors.error),
                  onPressed: onRemove,
                  tooltip: 'Remove variant',
                )
              else
                const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onSetDefault,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDefault
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 18,
                    color: isDefault
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isDefault ? 'Default variant' : 'Set as default',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDefault
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: isDefault
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}