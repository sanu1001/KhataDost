import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_search_index.dart';
import '../../domain/repositories/customer_repository.dart';
import 'customers_event.dart';
import 'customers_state.dart';

class CustomersBloc extends Bloc<CustomersEvent, CustomersState> {
  final CustomerRepository _repository;

  CustomersBloc(this._repository) : super(const CustomersState()) {
    on<CustomersLoadRequested>(_onLoadRequested);
    on<CustomerAdded>(_onCustomerAdded);
    on<CustomerUpdated>(_onCustomerUpdated);
    on<CustomerDeleted>(_onCustomerDeleted);
    on<CustomerSearchChanged>(_onSearchChanged);
  }

  // ── Load ──────────────────────────────────────────────
  Future<void> _onLoadRequested(
      CustomersLoadRequested event,
      Emitter<CustomersState> emit,
      ) async {
    emit(state.copyWith(status: CustomersStatus.loading, clearError: true));
    try {
      final customers = await _repository.getCustomers();
      _emitLoaded(emit, customers);
    } catch (_) {
      emit(state.copyWith(
        status: CustomersStatus.error,
        errorMessage: 'Failed to load customers',
      ));
    }
  }

  // ── Add ───────────────────────────────────────────────
  Future<void> _onCustomerAdded(
      CustomerAdded event,
      Emitter<CustomersState> emit,
      ) async {
    try {
      final added = await _repository.addCustomer(
        name: event.name,
        phone: event.phone,
        email: event.email,
        notes: event.notes,
      );
      final customers = [...state.customers, added]
        ..sort((a, b) => a.name.compareTo(b.name));
      _emitLoaded(emit, customers);
    } catch (_) {
      emit(state.copyWith(errorMessage: 'Failed to add customer'));
    }
  }

  // ── Update ────────────────────────────────────────────
  Future<void> _onCustomerUpdated(
      CustomerUpdated event,
      Emitter<CustomersState> emit,
      ) async {
    try {
      final updated = await _repository.updateCustomer(
        id: event.id,
        name: event.name,
        phone: event.phone,
        email: event.email,
        notes: event.notes,
      );
      final customers = state.customers
          .map((c) => c.id == updated.id ? updated : c)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      _emitLoaded(emit, customers);
    } catch (_) {
      emit(state.copyWith(errorMessage: 'Failed to update customer'));
    }
  }

  // ── Delete ────────────────────────────────────────────
  Future<void> _onCustomerDeleted(
      CustomerDeleted event,
      Emitter<CustomersState> emit,
      ) async {
    try {
      await _repository.deleteCustomer(event.id);
      final customers =
      state.customers.where((c) => c.id != event.id).toList();
      _emitLoaded(emit, customers);
    } catch (_) {
      emit(state.copyWith(errorMessage: 'Failed to delete customer'));
    }
  }

  // ── Search ────────────────────────────────────────────
  void _onSearchChanged(
      CustomerSearchChanged event,
      Emitter<CustomersState> emit,
      ) {
    // No repository call, no index rebuild — only re-filter.
    emit(state.copyWith(
      searchQuery: event.query,
      visibleCustomers:
      _filterVisible(state.customers, state.searchIndex, event.query),
    ));
  }

  // ── Helpers ───────────────────────────────────────────

  /// After any list mutation: rebuild the index and recompute the visible
  /// list against the CURRENT query, then emit one consistent snapshot.
  void _emitLoaded(Emitter<CustomersState> emit, List<Customer> customers) {
    final index = CustomerSearchIndex.build(customers);
    emit(state.copyWith(
      status: CustomersStatus.loaded,
      customers: customers,
      searchIndex: index,
      visibleCustomers: _filterVisible(customers, index, state.searchQuery),
      clearError: true,
    ));
  }

  /// Pure: filter the (already sorted) master list by the matched ids.
  /// Filtering a sorted list preserves alphabetical order for free.
  List<Customer> _filterVisible(
      List<Customer> customers,
      CustomerSearchIndex? index,
      String query,
      ) {
    if (query.trim().isEmpty || index == null) return customers;
    final matchedIds = index.query(query);
    return customers.where((c) => matchedIds.contains(c.id)).toList();
  }
}