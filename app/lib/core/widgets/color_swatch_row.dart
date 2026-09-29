import 'package:flutter/material.dart';

/// Scrollable row of circular color swatches for the clock color picker,
/// ending in a "Custom" rainbow swatch that opens a full picker.
/// The selected swatch shows a white ring. Touch targets are ≥ 44dp.
class ColorSwatchRow extends StatelessWidget {
  const ColorSwatchRow({
    super.key,
    required this.colors,
    required this.selectedColor,
    required this.onSelected,
    this.onCustomTap,
  });

  final List<Color> colors;
  final Color selectedColor;
  final ValueChanged<Color> onSelected;

  /// Opens the full custom color picker. Omit to hide the trailing "Custom"
  /// swatch entirely (e.g. a caller that only wants the fixed presets).
  final VoidCallback? onCustomTap;

  /// Original 4-color palette - kept as the leading entries of
  /// [curatedColors] so any existing saved selection still matches a preset
  /// swatch exactly.
  static const List<Color> defaultColors = [
    Color(0xFFFFFFFF),
    Color(0xFF111111),
    Color(0xFF9AA6B2),
    Color(0xFFE7D9BE),
  ];

  /// Curated, wallpaper-friendly palette - a superset of [defaultColors].
  /// Deliberately a fixed, hand-picked set (not a generated ramp) so it stays
  /// clean and useful rather than overwhelming.
  static const List<Color> curatedColors = [
    // Neutrals
    Color(0xFFFFFFFF), // Pure White
    Color(0xFFF5F5F5), // Soft White
    Color(0xFFD9D9D9), // Light Gray
    Color(0xFFC0C0C0), // Silver
    Color(0xFF9AA6B2), // Medium Gray (original default)
    Color(0xFF36393F), // Charcoal
    Color(0xFF111111), // Black (original default)
    // Reds
    Color(0xFFE53935), // Red
    Color(0xFFFF1744), // Bright Red
    Color(0xFFDC143C), // Crimson
    Color(0xFF800020), // Burgundy
    Color(0xFFFF7F6E), // Coral
    // Oranges
    Color(0xFFFF7A00), // Orange
    Color(0xFFE65100), // Deep Orange
    Color(0xFFFFC107), // Amber
    Color(0xFFB87333), // Copper
    // Yellows
    Color(0xFFFFEB3B), // Yellow
    Color(0xFFFFD700), // Gold
    Color(0xFFE1B12C), // Warm Gold
    Color(0xFFFFF44F), // Lemon
    // Greens
    Color(0xFFCDDC39), // Lime
    Color(0xFF43A047), // Green
    Color(0xFF50C878), // Emerald
    Color(0xFF98FF98), // Mint
    Color(0xFF00897B), // Teal
    // Blues
    Color(0xFF00E5FF), // Cyan
    Color(0xFF87CEEB), // Sky Blue
    Color(0xFF2196F3), // Blue
    Color(0xFF4169E1), // Royal Blue
    Color(0xFF001F54), // Navy
    // Purples
    Color(0xFF9C27B0), // Purple
    Color(0xFF8F00FF), // Violet
    Color(0xFF4B0082), // Indigo
    Color(0xFFE6E6FA), // Lavender
    // Pinks
    Color(0xFFF48FB1), // Pink
    Color(0xFFFF69B4), // Hot Pink
    Color(0xFFE0BFB8), // Rose
    Color(0xFFFF00FF), // Magenta
    // Warm cream (original default, kept for exact backward-compat match)
    Color(0xFFE7D9BE),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final color in colors) ...[
            _Swatch(
              color: color,
              selected: color.toARGB32() == selectedColor.toARGB32(),
              onTap: () => onSelected(color),
            ),
            const SizedBox(width: 14),
          ],
          if (onCustomTap != null) _CustomSwatch(onTap: onCustomTap!),
        ],
      ),
    );
  }
}

/// Trailing swatch that opens the full custom color picker - a rainbow-ring
/// circle so it reads as "any color" rather than one more fixed preset.
class _CustomSwatch extends StatelessWidget {
  const _CustomSwatch({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Custom color',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0xFFFF0000),
                    Color(0xFFFFFF00),
                    Color(0xFF00FF00),
                    Color(0xFF00FFFF),
                    Color(0xFF0000FF),
                    Color(0xFFFF00FF),
                    Color(0xFFFF0000),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Icon(Icons.add, size: 12, color: Colors.black87),
                ),
              ),
            ),
          ),
        ),
      ),
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
