import 'package:flutter/material.dart';
import '../../../../core/shell/shell_actions.dart';
import '../../../../core/widgets/placeholder_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(title: 'Settings', actions: [ShellActions()],);
  }
}