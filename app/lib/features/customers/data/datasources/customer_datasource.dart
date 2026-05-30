import '../models/customer_model.dart';

abstract class CustomerDatasource {
  Future<List<CustomerModel>> getCustomers();

  Future<CustomerModel> addCustomer({
    required String name,
    required String phone,
    String? email,
    String? notes,
  });

  Future<CustomerModel> updateCustomer({
    required String id,
    required String name,
    required String phone,
    String? email,
    String? notes,
  });

  Future<void> deleteCustomer(String id);
}