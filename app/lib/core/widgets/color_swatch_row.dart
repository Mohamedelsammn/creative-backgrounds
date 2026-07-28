import 'package:flutter/material.dart';

/// Row of circular color swatches for the clock color picker.
/// The selected swatch shows a white ring. Touch targets are ≥ 44dp.
class ColorSwatchRow extends StatelessWidget {
  const ColorSwatchRow({
    super.key,
    required this.colors,
    required this.selectedColor,
    required this.onSelected,
  });

  final List<Color> colors;
  final Color selectedColor;
  final ValueChanged<Color> onSelected;

  /// Default clock color palette: white, black, gray-blue, warm cream.
  static const List<Color> defaultColors = [
    Color(0xFFFFFFFF),
    Color(0xFF111111),
    Color(0xFF9AA6B2),
    Color(0xFFE7D9BE),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final color in colors) ...[
          _Swatch(
            color: color,
            selected: color.toARGB32() == selectedColor.toARGB32(),
            onTap: () => onSelected(color),
          ),
          const SizedBox(width: 14),
        ],
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Clock color',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white : Colors.white24,
                  width: selected ? 3 : 1,
                ),
                boxShadow: selected
                    ? const [
                        BoxShadow(color: Color(0x55000000), blurRadius: 6),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
