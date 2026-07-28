import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

/// Horizontal row of selectable pill chips (Position, Font in Customize).
///
/// Styled for the dark frosted panel by default: selected = white fill / black
/// text; unselected = translucent white fill / white70 text.
class OptionChipRow extends StatelessWidget {
  const OptionChipRow({
    super.key,
    required this.options,
    required this.selectedOption,
    required this.onSelected,
    this.expand = true,
  });

  final List<String> options;
  final String selectedOption;
  final ValueChanged<String> onSelected;

  /// When true, chips share the width equally (matches the Customize design).
  /// When false, chips size to content in a scrollable row.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      for (final option in options)
        _Chip(
          label: option,
          selected: option == selectedOption,
          onTap: () => onSelected(option),
          expand: expand,
        ),
    ];

    if (expand) {
      return Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            Expanded(child: chips[i]),
            if (i != chips.length - 1) const SizedBox(width: 8),
          ],
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            chips[i],
            if (i != chips.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.expand,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: expand ? 0 : 18),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.black : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
