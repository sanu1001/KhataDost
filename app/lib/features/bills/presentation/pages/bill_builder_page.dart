import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/navigation/navigation_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../domain/entities/draft_line.dart';
import '../bloc/bill_builder_bloc.dart';
import 'widgets/formats.dart';
import 'widgets/item_pick_sheet.dart';
import 'widgets/line_cards.dart';

/// THE notebook (§9): a list of fully-editable line cards, a running
/// total, and three add paths — scan more, search inventory, misc.
///
/// Reached from BOTH on-ramps (center Scan FAB with [scanOnOpen], Bills
/// tab "+"); both land on the same GetIt-singleton [BillBuilderBloc], so
/// there is exactly ONE draft.
class BillBuilderPage extends StatefulWidget {
  const BillBuilderPage({super.key, this.scanOnOpen = false});

  /// FAB path: open the capture sheet immediately on first frame.
  final bool scanOnOpen;

  @override
  State<BillBuilderPage> createState() => _BillBuilderPageState();
}

class _BillBuilderPageState extends State<BillBuilderPage> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.scanOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openScanSheet();
      });
    }
  }

  // ── Capture (camera for the counter, gallery for the emulator) ──────────

  Future<void> _openScanSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Scan products',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _ScanSourceTile(
                icon: Icons.photo_camera_outlined,
                title: 'Camera',
                subtitle: 'Point at the products on the counter',
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              const SizedBox(height: 10),
              _ScanSourceTile(
                icon: Icons.photo_library_outlined,
                title: 'Gallery',
                subtitle: 'Pick an existing photo',
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _pickAndScan(source);
  }

  Future<void> _pickAndScan(ImageSource source) async {
    final bloc = context.read<BillBuilderBloc>();
    try {
      // Downscale + recompress: keeps the upload light and well under the
      // server's 7 MB decoded cap. imageQuality forces JPEG output.
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (file == null) return; // user cancelled the system UI
      final bytes = await file.readAsBytes();
      bloc.add(ScanRequested(bytes));
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Could not open the camera — try Gallery.');
    }
  }

  // ── Discard draft ────────────────────────────────────────────────────────

  Future<void> _confirmDiscard() async {
    final bloc = context.read<BillBuilderBloc>();
    final nav = context.read<NavigationCubit>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Discard this bill?',
      message: 'All lines on the draft will be removed.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (confirmed) {
      bloc.add(const BillBuilderReset());
      nav.goBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BillBuilderBloc, BillBuilderState>(
      // Scan failure → toast; the draft itself is untouched (§4).
      listenWhen: (prev, curr) =>
          prev.scanStatus != curr.scanStatus &&
          curr.scanStatus == ScanStatus.failure,
      listener: (context, state) {
        AppSnackbar.error(context, state.scanMessage ?? 'Scan failed');
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('New Bill'),
            leading: BackButton(
              // Draft survives leaving — it's the notebook, not a form.
              onPressed: () => context.read<NavigationCubit>().goBack(),
            ),
            actions: [
              if (state.lines.isNotEmpty)
                IconButton(
                  tooltip: 'Discard draft',
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error, size: 22),
                  onPressed: _confirmDiscard,
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (state.isScanning) ...[
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Scanning photo…',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Expanded(
                  child: state.isEmpty && !state.isScanning
                      ? _EmptyDraft(onScan: _openScanSheet)
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 16),
                          itemCount: state.lines.length,
                          itemBuilder: (context, i) {
                            final line = state.lines[i];
                            return switch (line) {
                              UnitDraftLine() => UnitLineCard(
                                  key: ValueKey(line.id), line: line),
                              LooseDraftLine() => LooseLineCard(
                                  key: ValueKey(line.id), line: line),
                              MiscDraftLine() => MiscLineCard(
                                  key: ValueKey(line.id), line: line),
                            };
                          },
                        ),
                ),
                _AddRow(
                  onScan: _openScanSheet,
                  onAddItem: () => ItemPickSheet.show(context),
                  onAddMisc: () => context
                      .read<BillBuilderBloc>()
                      .add(const MiscLineAdded()),
                ),
                _TotalBar(
                  total: state.total,
                  canSettle: !state.isEmpty,
                  onSettle: () =>
                      context.read<NavigationCubit>().pushSettle(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScanSourceTile extends StatelessWidget {
  const _ScanSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 1),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDraft extends StatelessWidget {
  const _EmptyDraft({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 34, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          const Text(
            'Empty bill',
            style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Scan the counter, or add items below.',
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onScan,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 22),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
            label: const Text('Scan products'),
          ),
        ],
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.onScan,
    required this.onAddItem,
    required this.onAddMisc,
  });

  final VoidCallback onScan;
  final VoidCallback onAddItem;
  final VoidCallback onAddMisc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: _AddChip(
              icon: Icons.photo_camera_outlined,
              label: 'Scan',
              onTap: onScan,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AddChip(
              icon: Icons.search_rounded,
              label: 'Add item',
              onTap: onAddItem,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AddChip(
              icon: Icons.edit_note_rounded,
              label: 'Misc',
              onTap: onAddMisc,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySurface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({
    required this.total,
    required this.canSettle,
    required this.onSettle,
  });

  final double total;
  final bool canSettle;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D17131F),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Amount',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                Text(
                  '₹ ${formatMoney(total)}',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: canSettle ? onSettle : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 19),
            label: const Text('Settle'),
          ),
        ],
      ),
    );
  }
}
