part of 'inventory_bloc.dart';

enum InventoryStatus {initial, loading, loaded, error}

class InventoryState extends Equatable {
  final InventoryStatus status;
  final List<Item> items;
  final ItemSearchIndex? searchIndex;
  final String searchQuery;
  final List<Item> visibleItems;
  final String? errorMessage;

  const InventoryState({
    required this.status,
    required this.items,
    required this.searchIndex,
    required this.searchQuery,
    required this.visibleItems,
    required this.errorMessage,
  });

  factory InventoryState.initial() {
    return const InventoryState(
      status: InventoryStatus.initial,
      items: [],
      searchIndex: null,
      searchQuery: '',
      visibleItems: [],
      errorMessage: null,
    );
  }

  InventoryState copyWith({
    InventoryStatus? status,
    List<Item>? items,
    ItemSearchIndex? searchIndex,
    String? searchQuery,
    List<Item>? visibleItems,
    String? errorMessage,
    bool clearError = false,
  }){
    return InventoryState(
      status: status ?? this.status,
      items: items ?? this.items,
      searchIndex: searchIndex ?? this.searchIndex,
      searchQuery: searchQuery ?? this.searchQuery,
      visibleItems: visibleItems ?? this.visibleItems,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, items, searchQuery, visibleItems, errorMessage]; //searchIndex derived from items, and not Equatable
}

