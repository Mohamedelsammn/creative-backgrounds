import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/color_swatch_row.dart';
import '../../../../core/widgets/labeled_slider.dart';
import '../../../../core/widgets/option_chip_row.dart';
import '../../../../core/widgets/toggle_row.dart';
import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../clock/presentation/bloc/clock_bloc.dart';

/// Scrollable column of clock controls (Clock tab). Each control dispatches a
/// [ClockBloc] event which updates the live preview instantly.
class ClockSettingsPanel extends StatelessWidget {
  const ClockSettingsPanel({super.key});

  static const _positions = ['Top', 'Center', 'Bottom'];
  static const _fonts = ['Inter', 'Serif', 'Mono'];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClockBloc, ClockState>(
      builder: (context, state) {
        if (state is! ClockReady) {
          return const SizedBox(height: 200);
        }
        final config = state.config;
        final bloc = context.read<ClockBloc>();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('POSITION'),
            OptionChipRow(
              options: _positions,
              selectedOption: _positions[config.position.index],
              onSelected: (label) =>
                  bloc.add(ClockPositionChanged(_positionFrom(label))),
            ),
            const SizedBox(height: 20),
            _label('FONT'),
            OptionChipRow(
              options: _fonts,
              selectedOption: _fonts[config.font.index],
              onSelected: (label) => bloc.add(ClockFontChanged(_fontFrom(label))),
            ),
            const SizedBox(height: 20),
            _label('COLOR'),
            ColorSwatchRow(
              colors: ColorSwatchRow.defaultColors,
              selectedColor: Color(config.color),
              onSelected: (color) => bloc.add(ClockColorChanged(color.toARGB32())),
            ),
            const SizedBox(height: 20),
            LabeledSlider(
              label: 'Size',
              value: config.sizePx,
              min: 24,
              max: 120,
              valueSuffix: 'px',
              onChanged: (v) => bloc.add(ClockSizeChanged(v)),
            ),
            LabeledSlider(
              label: 'Opacity',
              value: config.opacity * 100,
              min: 0,
              max: 100,
              valueSuffix: '%',
              onChanged: (v) => bloc.add(ClockOpacityChanged(v / 100)),
            ),
            const SizedBox(height: 8),
            ToggleRow(
              label: 'Shadow',
              value: config.showShadow,
              onChanged: (v) => bloc.add(ClockShadowToggled(v)),
            ),
            ToggleRow(
              label: 'Glow',
              value: config.showGlow,
              onChanged: (v) => bloc.add(ClockGlowToggled(v)),
            ),
            ToggleRow(
              label: 'Stroke',
              value: config.showStroke,
              onChanged: (v) => bloc.add(ClockStrokeToggled(v)),
            ),
            ToggleRow(
              label: '24-Hour',
              value: config.is24Hour,
              onChanged: (v) => bloc.add(ClockHourFormatChanged(v)),
            ),
            ToggleRow(
              label: 'Date',
              value: config.showDate,
              onChanged: (v) => bloc.add(ClockDateToggled(v)),
            ),
            ToggleRow(
              label: 'Seconds',
              value: config.showSeconds,
              onChanged: (v) => bloc.add(ClockSecondsToggled(v)),
            ),
          ],
        );
      },
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: AppTextStyles.panelLabel),
      );

  ClockPosition _positionFrom(String label) => switch (label) {
        'Top' => ClockPosition.top,
        'Bottom' => ClockPosition.bottom,
        _ => ClockPosition.center,
      };

  ClockFont _fontFrom(String label) => switch (label) {
        'Serif' => ClockFont.serif,
        'Mono' => ClockFont.mono,
        _ => ClockFont.inter,
      };
}
