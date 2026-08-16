import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/draft_line.dart';
import '../../bloc/bill_builder_bloc.dart';
import 'cell_field.dart';
import 'formats.dart';

/// The three notebook cards (§10). Every cell is a [CellField] — editable
/// any time, nothing locks. All edits dispatch to [BillBuilderBloc] by
/// the line's local id; totals re-render from the next state emit.
///
/// Layout contract (survives 360 dp + large text scale):
///   row 1  name ………………………………………… ✕
///   row 2  ‹  variant — ₹price  1/N  ›     (unit cards only — the HERO
///                                           interaction gets full width)
///   row 3  QTY ⊖ n ⊕   PRICE ₹…   TOTAL ₹…  (captioned metric columns)
/// No fixed-height stacked-text containers (text-scale-proof), single-line
/// ellipsised texts, FittedBox on the total, ≥44 dp touch targets.

// ── Type A: swipeable variant card ───────────────────────────────────────────

class UnitLineCard extends StatelessWidget {
  const UnitLineCard({super.key, required this.line});

  final UnitDraftLine line;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BillBuilderBloc>();
    return _LineCardShell(
      lineId: line.id,
      name: line.name,
      rows: [
        _VariantSwiper(line: line),
        _MetricsRow(
          qty: _MetricGroup(
            label: 'QTY',
            child: _QtyStepper(
              value: line.count,
              onChanged: (q) => bloc.add(LineQuantityChanged(line.id, q)),
            ),
          ),
          price: _MetricGroup(
            label: 'PRICE',
            child: CellField(
              value: formatMoney(line.unitPrice),
              prefixText: '₹',
              onChanged: (t) {
                final v = double.tryParse(t);
                if (v != null && v >= 0) {
                  bloc.add(LinePriceChanged(line.id, v));
                }
              },
            ),
          ),
          total: line.lineTotal,
        ),
      ],
    );
  }
}

/// Swipe = variant = price (§10). Full-width, 48 dp, single-line content;
/// chevrons carry ≥44 dp tap areas (swipe still works on the whole strip).
class _VariantSwiper extends StatelessWidget {
  const _VariantSwiper({required this.line});

  final UnitDraftLine line;

  void _step(BuildContext context, int delta) {
    final variants = line.item.variants;
    if (variants.length < 2) return;
    final i = variants.indexWhere((v) => v.id == line.selectedVariantId);
    final next = variants[(i + delta + variants.length) % variants.length];
    context.read<BillBuilderBloc>().add(VariantSwiped(line.id, next.id));
  }

  @override
  Widget build(BuildContext context) {
    final variants = line.item.variants;
    final hasMany = variants.length > 1;
    final index =
        variants.indexWhere((v) => v.id == line.selectedVariantId);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -150) _step(context, 1); // swipe left → next variant
        if (v > 150) _step(context, -1); // swipe right → previous
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (hasMany)
              _ChevronButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => _step(context, -1),
              )
            else
              const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: line.selectedVariant.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      TextSpan(
                        text:
                            '  ₹${formatMoney(line.selectedVariant.price)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (hasMany) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${index + 1}/${variants.length}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              _ChevronButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => _step(context, 1),
              ),
            ] else
              const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 44,
        height: 48,
        child: Icon(icon, size: 23, color: AppColors.primary),
      ),
    );
  }
}

// ── Type B: typed-measure loose card (live recompute) ────────────────────────

class LooseLineCard extends StatelessWidget {
  const LooseLineCard({super.key, required this.line});

  final LooseDraftLine line;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BillBuilderBloc>();
    final unitUpper = line.item.unit.toUpperCase();
    return _LineCardShell(
      lineId: line.id,
      name: line.name,
      rows: [
        _MetricsRow(
          qty: _MetricGroup(
            label: 'QTY ($unitUpper)',
            child: SizedBox(
              width: 96,
              child: CellField(
                value: line.measure == 0 ? '' : formatQty(line.measure),
                hint: '0.0',
                autofocus: line.measure == 0,
                onChanged: (t) {
                  final v = double.tryParse(t);
                  if (v != null && v >= 0) {
                    bloc.add(LineQuantityChanged(line.id, v));
                  }
                },
              ),
            ),
          ),
          price: _MetricGroup(
            label: 'RATE/$unitUpper',
            child: CellField(
              value: formatMoney(line.unitPrice),
              prefixText: '₹',
              onChanged: (t) {
                final v = double.tryParse(t);
                if (v != null && v >= 0) {
                  bloc.add(LinePriceChanged(line.id, v));
                }
              },
            ),
          ),
          total: line.lineTotal,
        ),
      ],
    );
  }
}

// ── Miscellaneous: the escape hatch ──────────────────────────────────────────

class MiscLineCard extends StatelessWidget {
  const MiscLineCard({super.key, required this.line});

  final MiscDraftLine line;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BillBuilderBloc>();
    return _LineCardShell(
      lineId: line.id,
      name: line.name,
      nameHint: 'Item name',
      nameAutofocus: line.name.isEmpty,
      badge: 'misc',
      rows: [
        _MetricsRow(
          qty: _MetricGroup(
            label: 'QTY',
            child: _QtyStepper(
              value: line.count,
              onChanged: (q) => bloc.add(LineQuantityChanged(line.id, q)),
            ),
          ),
          price: _MetricGroup(
            label: 'PRICE',
            child: CellField(
              value: formatMoney(line.price),
              hint: 'price',
              prefixText: '₹',
              onChanged: (t) {
                final v = double.tryParse(t);
                if (v != null && v >= 0) {
                  bloc.add(LinePriceChanged(line.id, v));
                }
              },
            ),
          ),
          total: line.lineTotal,
        ),
      ],
    );
  }
}

// ── Shared card chrome ───────────────────────────────────────────────────────

/// Name row (editable) + remove ✕ on top, then the type-specific rows,
/// 12 dp apart on a 16 dp card inset (8-point grid throughout).
class _LineCardShell extends StatelessWidget {
  const _LineCardShell({
    required this.lineId,
    required this.name,
    required this.rows,
    this.nameHint,
    this.nameAutofocus = false,
    this.badge,
  });

  final String lineId;
  final String name;
  final List<Widget> rows;
  final String? nameHint;
  final bool nameAutofocus;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BillBuilderBloc>();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: CellField(
                    value: name,
                    hint: nameHint ?? 'Name',
                    autofocus: nameAutofocus,
                    keyboardType: TextInputType.text,
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    onChanged: (t) => bloc.add(LineNameChanged(lineId, t)),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove line',
                  icon: const Icon(Icons.close_rounded,
                      size: 19, color: AppColors.textSecondary),
                  onPressed: () => bloc.add(LineRemoved(lineId)),
                ),
              ],
            ),
            for (final row in rows) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: row,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The captioned bottom strip shared by all three cards:
/// QTY-ish (fixed) · PRICE-ish (flexes) · TOTAL (the loudest number).
class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.qty,
    required this.price,
    required this.total,
  });

  final Widget qty;
  final Widget price;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        qty,
        const SizedBox(width: 12),
        Expanded(child: price),
        const SizedBox(width: 12),
        _MetricGroup(
          label: 'TOTAL',
          alignEnd: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 104, minHeight: 40),
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '₹${formatMoney(total)}',
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tiny uppercase caption over a control — values stay louder than labels.
class _MetricGroup extends StatelessWidget {
  const _MetricGroup({
    required this.label,
    required this.child,
    this.alignEnd = false,
  });

  final String label;
  final Widget child;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.textHint,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove_rounded,
          enabled: value > 1,
          onTap: () => onChanged(value - 1),
        ),
        SizedBox(
          width: 48,
          child: CellField(
            value: formatQty(value),
            onChanged: (t) {
              final v = double.tryParse(t);
              if (v != null && v > 0) onChanged(v);
            },
          ),
        ),
        _StepButton(
          icon: Icons.add_rounded,
          enabled: true,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 36,
        height: 44,
        child: Icon(
          icon,
          size: 21,
          color: enabled ? AppColors.primary : AppColors.textHint,
        ),
      ),
    );
  }
}
