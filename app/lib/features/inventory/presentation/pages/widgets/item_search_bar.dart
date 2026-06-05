import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/theme/app_theme.dart'; // AppColors lives here — adjust if your path differs
import '../../bloc/inventory_bloc.dart';

class ItemSearchBar extends StatefulWidget {
  const ItemSearchBar({super.key});

  @override
  State<ItemSearchBar> createState() => _ItemSearchBarState();
}

class _ItemSearchBarState extends State<ItemSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) =>
      context.read<InventoryBloc>().add(InventorySearchChanged(value));

  void _clear() {
    _controller.clear();
    _onChanged('');
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search items',
        prefixIcon:
        const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (_, value, __) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
            icon: const Icon(Icons.close,
                size: 18, color: AppColors.textSecondary),
            onPressed: _clear,
          ),
        ),
        // fill / borders / radius / padding all inherited from inputDecorationTheme
      ),
    );
  }
}