import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../navigation/navigation_cubit.dart';

class ShellActions extends StatelessWidget {
  const ShellActions({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => context.read<NavigationCubit>().pushSettings(),
    );
  }
}