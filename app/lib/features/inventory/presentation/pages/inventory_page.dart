import 'package:flutter/material.dart';
import '../../../../core/shell/shell_actions.dart';
import '../../../../core/widgets/placeholder_page.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(title: 'Inventory', actions: [ShellActions()],);
  }
}