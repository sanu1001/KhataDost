import 'package:equatable/equatable.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_search_index.dart';

enum CustomersStatus { initial, loading, loaded, error }

class CustomersState extends Equatable {
  final CustomersStatus status;
  final List<Customer> customers;          // SOURCE OF TRUTH — full, alphabetical
  final CustomerSearchIndex? searchIndex;  // DERIVED from customers
  final String searchQuery;                // SOURCE OF TRUTH — '' means show all
  final List<Customer> visibleCustomers;   // DERIVED from customers + index + query
  final String? errorMessage;

  const CustomersState({
    this.status = CustomersStatus.initial,
    this.customers = const [],
    this.searchIndex,
    this.searchQuery = '',
    this.visibleCustomers = const [],
    this.errorMessage,
  });

  CustomersState copyWith({
    CustomersStatus? status,
    List<Customer>? customers,
    CustomerSearchIndex? searchIndex,
    String? searchQuery,
    List<Customer>? visibleCustomers,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CustomersState(
      status: status ?? this.status,
      customers: customers ?? this.customers,
      searchIndex: searchIndex ?? this.searchIndex,
      searchQuery: searchQuery ?? this.searchQuery,
      visibleCustomers: visibleCustomers ?? this.visibleCustomers,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    customers,
    searchQuery,
    visibleCustomers,
    errorMessage,
    // searchIndex is intentionally NOT here — see note below
  ];
}