import 'package:flutter/material.dart';
import '../../../domain/entities/customer.dart';

class CustomerListTile extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const CustomerListTile({
    super.key,
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(customer.name),
      subtitle: Text(customer.phone),
      onTap: onTap,
    );
  }
}