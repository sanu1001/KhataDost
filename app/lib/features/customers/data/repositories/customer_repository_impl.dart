import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../datasources/customer_datasource.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final CustomerDatasource _datasource;

  const CustomerRepositoryImpl(this._datasource);

  @override
  Future<List<Customer>> getCustomers() => _datasource.getCustomers();

  @override
  Future<Customer> addCustomer({
    required String name,
    required String phone,
    String? email,
    String? notes,
  }) =>
      _datasource.addCustomer(
        name: name,
        phone: phone,
        email: email,
        notes: notes,
      );

  @override
  Future<Customer> updateCustomer({
    required String id,
    required String name,
    required String phone,
    String? email,
    String? notes,
  }) =>
      _datasource.updateCustomer(
        id: id,
        name: name,
        phone: phone,
        email: email,
        notes: notes,
      );

  @override
  Future<void> deleteCustomer(String id) => _datasource.deleteCustomer(id);
}