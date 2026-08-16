import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/navigation_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../domain/entities/item.dart';
import '../bloc/inventory_bloc.dart';
import 'widgets/variant_row.dart';

/// Local data holder for one variant row's form state.
/// Lives here (not in the BLoC) — it's UI state only.
class _VariantDraft {
  final TextEditingController labelCtrl;
  final TextEditingController priceCtrl;
  bool isDefault;

  _VariantDraft({
    this.isDefault = false,
    String? label,
    String? price,
  })  : labelCtrl = TextEditingController(text: label ?? ''),
        priceCtrl = TextEditingController(text: price ?? '');

  void dispose() {
    labelCtrl.dispose();
    priceCtrl.dispose();
  }
}

class ItemFormPage extends StatefulWidget {
  final String? itemId; // null = add mode, non-null = edit mode

  const ItemFormPage({super.key, this.itemId});

  bool get isEditMode => itemId != null;

  @override
  State<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends State<ItemFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final List<_VariantDraft> _variants = [];
  String _pricingType = 'unit';

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode) {
      _prefill();
    } else {
      _variants.add(_VariantDraft(isDefault: true));
    }
  }

  void _prefill() {
    final state = context.read<InventoryBloc>().state;
    final matches = state.items.where((i) => i.id == widget.itemId);
    if (matches.isEmpty) return;
    final item = matches.first;
    _nameCtrl.text = item.name;
    switch (item) {
      case UnitItem():
        _pricingType = 'unit';
      case LooseItem(:final rate, :final unit):
        _pricingType = 'loose';
        _rateCtrl.text = rate == rate.roundToDouble()
            ? rate.toStringAsFixed(0)
            : rate.toStringAsFixed(2);
        _unitCtrl.text = unit;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rateCtrl.dispose();
    _unitCtrl.dispose();
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  void _setDefault(int index) {
    setState(() {
      for (var i = 0; i < _variants.length; i++) {
        _variants[i].isDefault = i == index;
      }
    });
  }

  void _addVariantRow() =>
      setState(() => _variants.add(_VariantDraft()));

  void _removeVariantRow(int index) {
    setState(() {
      final wasDefault = _variants[index].isDefault;
      _variants[index].dispose();
      _variants.removeAt(index);
      if (wasDefault && _variants.isNotEmpty) {
        _variants.first.isDefault = true;
      }
    });
  }

  List<ItemVariant> _buildVariants() {
    return _variants.asMap().entries.map((e) => ItemVariant(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}_${e.key}',
      label: e.value.labelCtrl.text.trim(),
      price: double.parse(e.value.priceCtrl.text.trim()),
      isDefault: e.value.isDefault,
    )).toList();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!widget.isEditMode &&
        _pricingType == 'unit' &&
        _variants.isEmpty) {
      AppSnackbar.error(context, 'Add at least one variant');
      return;
    }

    if (widget.isEditMode) {
      context.read<InventoryBloc>().add(ItemUpdated(
        id: widget.itemId!,
        name: _nameCtrl.text.trim(),
        rate: _pricingType == 'loose'
            ? double.tryParse(_rateCtrl.text)
            : null,
        unit: _pricingType == 'loose' ? _unitCtrl.text.trim() : null,
      ));
      AppSnackbar.success(context, 'Changes saved');
    } else {
      context.read<InventoryBloc>().add(ItemAdded(
        name: _nameCtrl.text.trim(),
        pricingType: _pricingType,
        variants:
        _pricingType == 'unit' ? _buildVariants() : null,
        rate: _pricingType == 'loose'
            ? double.tryParse(_rateCtrl.text)
            : null,
        unit: _pricingType == 'loose'
            ? _unitCtrl.text.trim()
            : null,
      ));
      AppSnackbar.success(context, '"${_nameCtrl.text.trim()}" added');
    }
    context.read<NavigationCubit>().goBack();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Edit Item' : 'Add Item'),
        leading: BackButton(
          onPressed: () => context.read<NavigationCubit>().goBack(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          // Bottom inset clears the shell's floating glass bar (extendBody).
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.paddingOf(context).bottom + 16),
          children: [
            // Pricing type — interactive toggle in add mode, badge in edit
            if (!widget.isEditMode) ...[
              _PricingTypeToggle(
                selected: _pricingType,
                onChanged: (type) {
                  setState(() {
                    _pricingType = type;
                    if (type == 'loose') {
                      for (final v in _variants) {
                        v.dispose();
                      }
                      _variants.clear();
                    } else if (_variants.isEmpty) {
                      _variants.add(_VariantDraft(isDefault: true));
                    }
                  });
                },
              ),
            ] else ...[
              _EditTypeBadge(pricingType: _pricingType),
            ],

            const SizedBox(height: 16),

            // Item name
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Item name'),
              textCapitalization: TextCapitalization.words,
              autofocus: !widget.isEditMode,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Name is required'
                  : null,
            ),

            const SizedBox(height: 16),

            // Type-specific fields
            if (_pricingType == 'unit' && !widget.isEditMode) ...[
              _VariantsSection(
                variants: _variants,
                onSetDefault: _setDefault,
                onRemove: _removeVariantRow,
                onAdd: _addVariantRow,
              ),
            ] else if (_pricingType == 'unit' && widget.isEditMode) ...[
              // Variant editing is on the detail page — keep form focused
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 17, color: AppColors.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Edit, add, or remove variants from the item detail page.',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _LooseFields(
                  rateCtrl: _rateCtrl, unitCtrl: _unitCtrl),
            ],

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _submit,
              child: Text(
                  widget.isEditMode ? 'Save changes' : 'Create item'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Type toggle (add mode) ─────────────────────────────────────────────────

class _PricingTypeToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _PricingTypeToggle(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pricing type',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TypeChip(
                label: 'Unit / Packaged',
                icon: Icons.shopping_bag_outlined,
                selected: selected == 'unit',
                onTap: () => onChanged('unit'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TypeChip(
                label: 'Loose / Weight',
                icon: Icons.scale_outlined,
                selected: selected == 'loose',
                onTap: () => onChanged('loose'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip(
      {required this.label,
        required this.icon,
        required this.selected,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 22,
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Type badge (edit mode — non-interactive) ──────────────────────────────

class _EditTypeBadge extends StatelessWidget {
  final String pricingType;
  const _EditTypeBadge({required this.pricingType});

  @override
  Widget build(BuildContext context) {
    final isUnit = pricingType == 'unit';
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(
            isUnit
                ? Icons.shopping_bag_outlined
                : Icons.scale_outlined,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            isUnit ? 'Unit / Packaged' : 'Loose / Weight',
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary),
          ),
          const Spacer(),
          const Text('Cannot change',
              style: TextStyle(
                  fontSize: 11, color: AppColors.textHint)),
        ],
      ),
    );
  }
}

// ── Variants section (add mode, unit type) ─────────────────────────────────

class _VariantsSection extends StatelessWidget {
  final List<_VariantDraft> variants;
  final void Function(int) onSetDefault;
  final void Function(int) onRemove;
  final VoidCallback onAdd;

  const _VariantsSection({
    required this.variants,
    required this.onSetDefault,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Variants',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                )),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Add variant'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(
          variants.length,
              (i) => VariantRow(
            index: i,
            labelController: variants[i].labelCtrl,
            priceController: variants[i].priceCtrl,
            isDefault: variants[i].isDefault,
            onSetDefault: () => onSetDefault(i),
            onRemove: variants.length > 1 ? () => onRemove(i) : null,
          ),
        ),
      ],
    );
  }
}

// ── Loose item fields ──────────────────────────────────────────────────────

class _LooseFields extends StatelessWidget {
  final TextEditingController rateCtrl;
  final TextEditingController unitCtrl;
  const _LooseFields(
      {required this.rateCtrl, required this.unitCtrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: rateCtrl,
          keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Rate per unit (₹)',
            hintText: 'e.g. 20',
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Rate is required';
            if (double.tryParse(v) == null) return 'Enter a valid number';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: unitCtrl,
          decoration: const InputDecoration(
            labelText: 'Unit',
            hintText: 'kg / g / litre / piece',
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Unit is required'
              : null,
        ),
      ],
    );
  }
}
