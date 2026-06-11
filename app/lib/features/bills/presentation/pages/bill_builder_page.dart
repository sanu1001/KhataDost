import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/navigation/navigation_cubit.dart';
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Scan products',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              dense: true,
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not open the camera — try Gallery.')),
      );
    }
  }

  // ── Discard draft ────────────────────────────────────────────────────────

  Future<void> _confirmDiscard() async {
    final bloc = context.read<BillBuilderBloc>();
    final nav = context.read<NavigationCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this bill?'),
        content: const Text('All lines on the draft will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.scanMessage ?? 'Scan failed')),
        );
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
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _confirmDiscard,
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (state.isScanning) ...[
                  const LinearProgressIndicator(),
                  const ListTile(
                    dense: true,
                    leading: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: Text('Scanning photo…'),
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

class _EmptyDraft extends StatelessWidget {
  const _EmptyDraft({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 56, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            'Empty bill',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Scan the counter, or add items below.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Scan'),
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
            child: OutlinedButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Scan'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onAddItem,
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Add item'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onAddMisc,
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('Misc'),
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total',
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)),
                Text(
                  '₹${formatMoney(total)}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: canSettle ? onSettle : null,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Settle'),
          ),
        ],
      ),
    );
  }
}
