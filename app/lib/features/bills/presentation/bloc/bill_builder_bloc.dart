import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../inventory/domain/entities/item.dart';
import '../../domain/bill_math.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/draft_line.dart';
import '../../domain/repositories/billing_repository.dart';
import '../../domain/repositories/scan_repository.dart';

part 'bill_builder_event.dart';
part 'bill_builder_state.dart';

/// THE draft bill — one instance app-wide (GetIt singleton), so the
/// center Scan FAB and the Bills tab's manual flow feed the SAME notebook.
///
/// Owns the whole draft lifecycle: both on-ramps (scan merge + manual
/// add), every cell edit, the swipe-variant and live-measure semantics,
/// the running total, the settle inputs, and the submit. Scan is an event
/// here — not a separate bloc — so there is exactly one source of truth.
class BillBuilderBloc extends Bloc<BillBuilderEvent, BillBuilderState> {
  BillBuilderBloc({
    required BillingRepository billingRepository,
    required ScanRepository scanRepository,
  })  : _billingRepository = billingRepository,
        _scanRepository = scanRepository,
        super(BillBuilderState.initial()) {
    on<BillBuilderReset>(_onReset);
    on<ScanRequested>(_onScanRequested);
    on<ItemPicked>(_onItemPicked);
    on<MiscLineAdded>(_onMiscLineAdded);
    on<LineRemoved>(_onLineRemoved);
    on<VariantSwiped>(_onVariantSwiped);
    on<LineQuantityChanged>(_onLineQuantityChanged);
    on<LinePriceChanged>(_onLinePriceChanged);
    on<LineNameChanged>(_onLineNameChanged);
    on<SettleCustomerChanged>(_onSettleCustomerChanged);
    on<PayingNowChanged>(_onPayingNowChanged);
    on<BillSubmitted>(_onBillSubmitted);
  }

  final BillingRepository _billingRepository;
  final ScanRepository _scanRepository;

  /// Local draft-line ids. Monotonic counter, NOT millis — a scan merge
  /// adds several lines in the same tick and ids must not collide.
  int _seq = 0;
  String _nextId() => 'dl${_seq++}';

  // ── Draft lifecycle ─────────────────────────────────────────────────────

  void _onReset(BillBuilderReset event, Emitter<BillBuilderState> emit) {
    emit(BillBuilderState.initial());
  }

  // ── On-ramp 1: scan (§10 — the AI is a card-picker) ─────────────────────

  Future<void> _onScanRequested(
      ScanRequested event, Emitter<BillBuilderState> emit) async {
    emit(state.copyWith(
      scanStatus: ScanStatus.scanning,
      clearScanMessage: true,
    ));

    try {
      final result = await _scanRepository.scan(
        imageBase64: base64Encode(event.imageBytes),
        mimeType: 'image/jpeg', // image_picker re-encodes to JPEG
      );

      final newLines = <DraftLine>[];
      for (final match in result.matches) {
        final item = match.item;
        final qty =
            (match.detectedQuantity < 1 ? 1 : match.detectedQuantity)
                .toDouble();
        if (item is UnitItem) {
          // Card lands at its default variant; shopkeeper swipes to correct.
          final variantId =
              item.variants.any((v) => v.id == match.defaultVariantId)
                  ? match.defaultVariantId
                  : defaultVariantOf(item).id;
          newLines.add(UnitDraftLine(
            id: _nextId(),
            item: item,
            selectedVariantId: variantId,
            count: qty,
          ));
        } else {
          // Matcher is Type A-only; if anything else ever arrives, keep the
          // detection as a misc line rather than dropping it silently.
          newLines.add(MiscDraftLine(
            id: _nextId(),
            name: match.detectedLabel,
            count: qty,
          ));
        }
      }
      for (final u in result.unmatched) {
        // "Not in inventory" → pre-filled misc line, price awaits typing.
        newLines.add(MiscDraftLine(
          id: _nextId(),
          name: u.label,
          count: (u.quantity < 1 ? 1 : u.quantity).toDouble(),
        ));
      }

      _emitLines(emit, [...state.lines, ...newLines],
          scanStatus: ScanStatus.idle);
    } on ApiException catch (e) {
      // 429/504 graceful degradation: toast + untouched draft (§4).
      emit(state.copyWith(
        scanStatus: ScanStatus.failure,
        scanMessage: e.message,
      ));
    } catch (_) {
      emit(state.copyWith(
        scanStatus: ScanStatus.failure,
        scanMessage: 'Scan failed — try again or add items manually.',
      ));
    }
  }

  // ── On-ramp 2: manual add ───────────────────────────────────────────────

  void _onItemPicked(ItemPicked event, Emitter<BillBuilderState> emit) {
    final item = event.item;
    final DraftLine line;
    switch (item) {
      case UnitItem():
        line = UnitDraftLine(
          id: _nextId(),
          item: item,
          selectedVariantId: defaultVariantOf(item).id,
        );
      case LooseItem():
        // Measure 0 until typed — the card's field takes focus.
        line = LooseDraftLine(id: _nextId(), item: item);
    }
    _emitLines(emit, [...state.lines, line]);
  }

  void _onMiscLineAdded(MiscLineAdded event, Emitter<BillBuilderState> emit) {
    _emitLines(emit, [...state.lines, MiscDraftLine(id: _nextId())]);
  }

  // ── Notebook edits (every cell, any time) ───────────────────────────────

  void _onLineRemoved(LineRemoved event, Emitter<BillBuilderState> emit) {
    _emitLines(
        emit, state.lines.where((l) => l.id != event.lineId).toList());
  }

  void _onVariantSwiped(VariantSwiped event, Emitter<BillBuilderState> emit) {
    _mutateLine(emit, event.lineId, (line) {
      if (line is UnitDraftLine) return line.swipeTo(event.variantId);
      return line;
    });
  }

  void _onLineQuantityChanged(
      LineQuantityChanged event, Emitter<BillBuilderState> emit) {
    _mutateLine(emit, event.lineId, (line) {
      return switch (line) {
        UnitDraftLine() => line.copyWith(count: event.quantity),
        LooseDraftLine() => line.copyWith(measure: event.quantity),
        MiscDraftLine() => line.copyWith(count: event.quantity),
      };
    });
  }

  void _onLinePriceChanged(
      LinePriceChanged event, Emitter<BillBuilderState> emit) {
    _mutateLine(emit, event.lineId, (line) {
      return switch (line) {
        UnitDraftLine() => line.copyWith(priceOverride: event.price),
        LooseDraftLine() => line.copyWith(rateOverride: event.price),
        MiscDraftLine() => line.copyWith(price: event.price),
      };
    });
  }

  void _onLineNameChanged(
      LineNameChanged event, Emitter<BillBuilderState> emit) {
    _mutateLine(emit, event.lineId, (line) {
      return switch (line) {
        UnitDraftLine() => line.copyWith(nameOverride: event.name),
        LooseDraftLine() => line.copyWith(nameOverride: event.name),
        MiscDraftLine() => line.copyWith(name: event.name),
      };
    });
  }

  // ── Settle inputs (§12) ─────────────────────────────────────────────────

  void _onSettleCustomerChanged(
      SettleCustomerChanged event, Emitter<BillBuilderState> emit) {
    if (event.customerId == null) {
      emit(state.copyWith(
        status: BillBuilderStatus.editing,
        clearCustomer: true,
        clearError: true,
      ));
    } else {
      emit(state.copyWith(
        status: BillBuilderStatus.editing,
        customerId: event.customerId,
        customerName: event.customerName,
        clearError: true,
      ));
    }
  }

  void _onPayingNowChanged(
      PayingNowChanged event, Emitter<BillBuilderState> emit) {
    if (event.amount == null) {
      // Cleared field → back to the default (= bill total).
      emit(state.copyWith(
        status: BillBuilderStatus.editing,
        clearPayingNow: true,
        clearError: true,
      ));
    } else {
      emit(state.copyWith(
        status: BillBuilderStatus.editing,
        payingNow: event.amount,
        clearError: true,
      ));
    }
  }

  // ── Submit (server recomputes all money; we surface its verdict) ────────

  Future<void> _onBillSubmitted(
      BillSubmitted event, Emitter<BillBuilderState> emit) async {
    if (state.lines.isEmpty) {
      emit(state.copyWith(
        status: BillBuilderStatus.failure,
        errorMessage: 'a bill needs at least one item',
      ));
      return;
    }

    emit(state.copyWith(
        status: BillBuilderStatus.submitting, clearError: true));

    try {
      final bill = await _billingRepository.createBill(
        customerId: state.customerId,
        amountPaid: state.effectivePayingNow,
        lines: state.lines,
      );
      emit(state.copyWith(
        status: BillBuilderStatus.success,
        lastCreatedBill: bill,
      ));
    } on ApiException catch (e) {
      // Walk-in 409 / validation 400 — the SERVER's message, inline.
      emit(state.copyWith(
        status: BillBuilderStatus.failure,
        errorMessage: e.message,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: BillBuilderStatus.failure,
        errorMessage: 'Could not save the bill',
      ));
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  void _mutateLine(Emitter<BillBuilderState> emit, String lineId,
      DraftLine Function(DraftLine) transform) {
    _emitLines(emit, [
      for (final l in state.lines) l.id == lineId ? transform(l) : l,
    ]);
  }

  /// Every line mutation funnels here: recompute the running total in the
  /// same emit (derived state, single consistent state — see customers'
  /// visibleCustomers).
  void _emitLines(Emitter<BillBuilderState> emit, List<DraftLine> lines,
      {ScanStatus? scanStatus}) {
    emit(state.copyWith(
      status: BillBuilderStatus.editing,
      lines: lines,
      total: billTotal(lines.map((l) => l.lineTotal)),
      scanStatus: scanStatus,
      clearError: true,
    ));
  }
}
