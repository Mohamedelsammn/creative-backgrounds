import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

/// Row with a label (left) and formatted value (right) above a [Slider].
/// Defaults to dark-panel styling (white text/track) used in Customize.
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.valueSuffix = '',
    this.divisions,
    this.onDark = true,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String valueSuffix;
  final int? divisions;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final labelColor = onDark ? Colors.white : Colors.black;
    final valueColor = onDark ? Colors.white70 : Colors.black54;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: AppTextStyles.bodyLarge.copyWith(color: labelColor)),
            Text(
              '${value.round()}$valueSuffix',
              style: AppTextStyles.bodyMedium.copyWith(color: valueColor),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: onDark ? Colors.white : Colors.black,
            inactiveTrackColor:
                (onDark ? Colors.white : Colors.black).withValues(alpha: 0.24),
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
            trackHeight: 3,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
