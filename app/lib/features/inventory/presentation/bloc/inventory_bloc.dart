import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:khata_dost/features/inventory/domain/repository/inventory_repository.dart';
import '../../domain/entities/item.dart';
import '../../domain/entities/item_search_index.dart';

part 'inventory_event.dart';
part 'inventory_state.dart';

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final InventoryRepository _repository;

  InventoryBloc(this._repository) : super(InventoryState.initial()) {
    on<InventoryLoadRequested>(_onLoadRequested);
    on<ItemAdded>(_onItemAdded);
    on<ItemUpdated>(_onItemUpdated);
    on<ItemDeleted>(_onItemDeleted);
    on<VariantAdded>(_onVariantAdded);
    on<VariantUpdated>(_onVariantUpdated);
    on<VariantDeleted>(_onVariantDeleted);
    on<InventorySearchChanged>(_onSearchChanged);
  }

  Future<void> _onLoadRequested(InventoryLoadRequested event, Emitter<InventoryState> emit) async {

    debugPrint('🔄 Inventory Load Requested fired');
    emit(state.copyWith(status: InventoryStatus.loading, clearError: true));

    try{
      final items = await _repository.getItems();
      _emitLoaded(emit, items);
    }catch(_){
      emit(state.copyWith(
        status: InventoryStatus.error,
        errorMessage: 'Inventory Load Failed!',
      ));
    }
  }

  Future<void> _onItemAdded(ItemAdded event, Emitter<InventoryState> emit) async {
    emit(state.copyWith(status: InventoryStatus.loading, clearError: true));
    try {
      await _repository.createItem( // could have done [...items,updatedItem or Added Item] one RTT but the repo already did the write, re-reading guarantees consistency without me reconstructing the list by hand.
        name: event.name,
        pricingType: event.pricingType,
        variants: event.variants,
        rate: event.rate,
        unit: event.unit,
      );
      final items = await _repository.getItems(); // re-fetch
      _emitLoaded(emit, items);                    // rebuilds index + visible
    } catch (_) {
      emit(state.copyWith(status: InventoryStatus.error, errorMessage: 'Could not add item'));
    }
  }

  Future<void> _onItemUpdated(ItemUpdated event, Emitter<InventoryState> emit) async {
    emit(state.copyWith(status: InventoryStatus.loading, clearError: true));
    try {
      await _repository.updateItem( // could have done [...items,updatedItem or Added Item] one RTT but the repo already did the write, re-reading guarantees consistency without me reconstructing the list by hand.
        id: event.id,
        name: event.name,
        rate: event.rate,
        unit: event.unit,
      );
      final items = await _repository.getItems(); // re-fetch
      _emitLoaded(emit, items);                    // rebuilds index + visible
    } catch (_) {
      emit(state.copyWith(status: InventoryStatus.error, errorMessage: 'Could not update item'));
    }
  }

  Future<void> _onItemDeleted(ItemDeleted event, Emitter<InventoryState> emit) async {
    emit(state.copyWith(status: InventoryStatus.loading, clearError: true));
    try {
      await _repository.deleteItem( // could have done [...items,updatedItem or Added Item] one RTT but the repo already did the write, re-reading guarantees consistency without me reconstructing the list by hand.
        id: event.id,
      );
      final items = await _repository.getItems(); // re-fetch
      _emitLoaded(emit, items);                    // rebuilds index + visible
    } catch (_) {
      emit(state.copyWith(status: InventoryStatus.error, errorMessage: 'Could not delete item'));
    }
  }

  Future<void> _onVariantAdded(VariantAdded event, Emitter<InventoryState> emit) async {
    emit(state.copyWith(status: InventoryStatus.loading, clearError: true));
    try {
      await _repository.addVariant( // could have done [...items,updatedItem or Added Item] one RTT but the repo already did the write, re-reading guarantees consistency without me reconstructing the list by hand.
        isDefault: event.isDefault,
        price: event.price,
        label: event.label,
        itemId: event.itemId,
      );
      final items = await _repository.getItems(); // re-fetch
      _emitLoaded(emit, items);                    // rebuilds index + visible
    } catch (_) {
      emit(state.copyWith(status: InventoryStatus.error, errorMessage: 'Could not add variant'));
    }
  }

  Future<void> _onVariantUpdated(VariantUpdated event, Emitter<InventoryState> emit) async {
    emit(state.copyWith(status: InventoryStatus.loading, clearError: true));
    try {
      await _repository.updateVariant(
        variantId: event.variantId, // could have done [...items,updatedItem or Added Item] one RTT but the repo already did the write, re-reading guarantees consistency without me reconstructing the list by hand.
        isDefault: event.isDefault,
        price: event.price,
        label: event.label,
        itemId: event.itemId,
      );
      final items = await _repository.getItems(); // re-fetch
      _emitLoaded(emit, items);                    // rebuilds index + visible
    } catch (_) {
      emit(state.copyWith(status: InventoryStatus.error, errorMessage: 'Could not update variant'));
    }
  }

  Future<void> _onVariantDeleted(VariantDeleted event, Emitter<InventoryState> emit) async {
    emit(state.copyWith(status: InventoryStatus.loading, clearError: true));
    try {
      await _repository.deleteVariant( // could have done [...items,updatedItem or Added Item] one RTT but the repo already did the write, re-reading guarantees consistency without me reconstructing the list by hand.
        itemId: event.itemId,
        variantId: event.variantId
      );
      final items = await _repository.getItems(); // re-fetch
      _emitLoaded(emit, items);                    // rebuilds index + visible
    } catch (_) {
      emit(state.copyWith(status: InventoryStatus.error, errorMessage: 'Could not delete variant'));
    }
  }


  Future<void> _onSearchChanged(InventorySearchChanged event, Emitter<InventoryState> emit) async {
    debugPrint('Search Changed Triggered');

    emit(state.copyWith(
      searchQuery: event.query,
      visibleItems: _recomputeVisible(state.items, state.searchIndex, event.query),
    ));
  }



  ///helpers
  void _emitLoaded(Emitter<InventoryState> emit, List<Item> items){
    final index = ItemSearchIndex.build(items);
    emit(state.copyWith(
      status: InventoryStatus.loaded,
      items: items,
      searchIndex: index,
      visibleItems: _recomputeVisible(items, index, state.searchQuery),
      clearError: true,

    ));
  }

  List<Item> _recomputeVisible(List<Item> items, ItemSearchIndex? index, String query,) {
    if (query.trim().isEmpty || index == null) return items;
    final matchedIds = index.query(query);
    return items.where((i) => matchedIds.contains(i.id)).toList();
  }


}
