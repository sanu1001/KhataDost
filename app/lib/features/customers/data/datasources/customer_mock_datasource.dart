import 'customer_datasource.dart';
import '../models/customer_model.dart';

class CustomerMockDatasource implements CustomerDatasource {
  // In-memory store. Mutations survive for the app session only.
  final List<CustomerModel> _customers = [
    const CustomerModel(id: 'c1', name: 'Anil Sen',      phone: '9000000001', hasDues: true),
    const CustomerModel(id: 'c2', name: 'Meena Devi',    phone: '9000000002', hasDues: false),
    const CustomerModel(id: 'c3', name: 'Suresh Sen',    phone: '9000000003', hasDues: false),
    const CustomerModel(id: 'c4', name: 'Sunita Kumari', phone: '9000000004', hasDues: true),
  ];

  @override
  Future<List<CustomerModel>> getCustomers() async {
    await Future.delayed(const Duration(milliseconds: 400));
    // Mirror the backend: return alphabetical by name.
    return [..._customers]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<CustomerModel> addCustomer({
    required String name,
    required String phone,
    String? email,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final customer = CustomerModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      phone: phone,
      email: email,
      notes: notes,
      hasDues: false, // new customers never start with dues
    );
    _customers.add(customer);
    return customer;
  }

  @override
  Future<CustomerModel> updateCustomer({
    required String id,
    required String name,
    required String phone,
    String? email,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _customers.indexWhere((c) => c.id == id);
    if (index == -1) throw Exception('Customer not found');
    final updated = CustomerModel(
      id: id,
      name: name,
      phone: phone,
      email: email,
      notes: notes,
      hasDues: _customers[index].hasDues, // preserve existing dues status
    );
    _customers[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteCustomer(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _customers.removeWhere((c) => c.id == id);
  }
}