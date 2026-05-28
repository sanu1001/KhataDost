import 'package:flutter/material.dart';
import '../../../../core/shell/shell_actions.dart';
import '../../../../core/widgets/placeholder_page.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(title: 'Customers', actions: [ShellActions()],);
  }
}