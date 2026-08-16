import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

class CustomerSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const CustomerSearchBar({super.key, required this.onChanged});

  @override
  State<CustomerSearchBar> createState() => _CustomerSearchBarState();
}

class _CustomerSearchBarState extends State<CustomerSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by name or phone number',
          prefixIcon: const Icon(Icons.search_rounded,
              size: 21, color: AppColors.textHint),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (_, value, __) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textSecondary),
                    onPressed: _clear,
                  ),
          ),
          // fill / borders / radius / padding inherited from the theme
        ),
      ),
    );
  }
}
