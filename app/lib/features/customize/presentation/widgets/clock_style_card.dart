import 'package:flutter/material.dart';

import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../clock/presentation/widgets/clock_painter.dart';

/// A single clock-style option: a static "09:41" rendered in the style, with a
/// label. Selected state shows a white border ring.
class ClockStyleCard extends StatelessWidget {
  const ClockStyleCard({
    super.key,
    required this.style,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ClockStyle style;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static final DateTime _sample = DateTime(2024, 1, 1, 9, 41);

  ClockFont _fontFor(ClockStyle style) => switch (style) {
        ClockStyle.elegant => ClockFont.serif,
        ClockStyle.digital => ClockFont.mono,
        _ => ClockFont.inter,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.10),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 46,
              child: CustomPaint(
                size: const Size(140, 46),
                painter: ClockPainter(
                  config: ClockConfigEntity(
                    style: style,
                    font: _fontFor(style),
                    sizePx: 30,
                    showDate: false,
                    showShadow: false,
                  ),
                  now: _sample,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
