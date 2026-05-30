import '../entities/customer.dart';

abstract class CustomerRepository {
  Future<List<Customer>> getCustomers();
  Future<Customer> addCustomer({
    required String name,
    required String phone,
    String? email,
    String? notes,
  });
  Future<Customer> updateCustomer({
    required String id,
    required String name,
    required String phone,
    String? email,
    String? notes,
  });
  Future<void> deleteCustomer(String id);
}