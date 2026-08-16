import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

/// An inline-editable notebook cell (§9: every cell editable, nothing
/// locks).
///
/// The classic controller-sync problem, solved once: the cell holds its
/// own [TextEditingController], and adopts an EXTERNAL value change (e.g.
/// a variant swipe re-pricing the line) only while the user is NOT typing
/// in it — so live state updates never fight the keyboard.
class CellField extends StatefulWidget {
  const CellField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.prefixText,
    this.suffixText,
    this.keyboardType =
        const TextInputType.numberWithOptions(decimal: true),
    this.textAlign = TextAlign.center,
    this.style,
    this.autofocus = false,
  });

  /// Canonical value from bloc state (already formatted for display).
  final String value;

  /// Raw text out — the caller parses/dispatches.
  final ValueChanged<String> onChanged;

  final String? hint;
  final String? prefixText;
  final String? suffixText;
  final TextInputType keyboardType;
  final TextAlign textAlign;
  final TextStyle? style;
  final bool autofocus;

  @override
  State<CellField> createState() => _CellFieldState();
}

class _CellFieldState extends State<CellField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    // On blur, snap the text back to the canonical formatted value
    // (e.g. '10.' typed mid-edit → '10.00' once the user moves on).
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _controller.text != widget.value) {
        _controller.text = widget.value;
      }
    });
  }

  @override
  void didUpdateWidget(CellField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      textAlign: widget.textAlign,
      style: widget.style ??
          const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        prefixText: widget.prefixText,
        suffixText: widget.suffixText,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.8),
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}
