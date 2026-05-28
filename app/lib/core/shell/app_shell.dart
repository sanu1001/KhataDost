import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../navigation/navigation_cubit.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTabTapped(BuildContext context, int index) {
    context.read<NavigationCubit>().goToTab(navigationShell, index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        onPressed: () => debugPrint('Scan FAB tapped'),
        shape: const CircleBorder(),
        child: const Icon(Icons.qr_code_scanner),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        notchMargin: 8,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              label: 'Home',
              index: 0,
              currentIndex: navigationShell.currentIndex,
              onTap: (i) => _onTabTapped(context, i),
            ),
            _NavItem(
              icon: Icons.receipt_long_outlined,
              label: 'Bills',
              index: 1,
              currentIndex: navigationShell.currentIndex,
              onTap: (i) => _onTabTapped(context, i),
            ),
            const SizedBox(width: 48),
            _NavItem(
              icon: Icons.inventory_2_outlined,
              label: 'Inventory',
              index: 2,
              currentIndex: navigationShell.currentIndex,
              onTap: (i) => _onTabTapped(context, i),
            ),
            _NavItem(
              icon: Icons.people_outline,
              label: 'Customers',
              index: 3,
              currentIndex: navigationShell.currentIndex,
              onTap: (i) => _onTabTapped(context, i),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Nav item ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    final color = isActive
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }
}