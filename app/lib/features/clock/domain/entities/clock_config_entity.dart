import 'package:equatable/equatable.dart';

enum ClockStyle { modern, minimal, elegant, digital }

enum ClockPosition { top, center, bottom }

enum ClockFont { inter, serif, mono }

/// All configurable clock properties. Rendered identically by the Flutter
/// preview (`ClockPainter`) and the native `ClockRenderer.kt`.
class ClockConfigEntity extends Equatable {
  const ClockConfigEntity({
    this.style = ClockStyle.modern,
    this.position = ClockPosition.center,
    this.font = ClockFont.inter,
    this.color = 0xFFFFFFFF,
    this.sizePx = 76,
    this.opacity = 1.0,
    this.showShadow = true,
    this.showGlow = false,
    this.showStroke = false,
    this.is24Hour = false,
    this.showDate = true,
    this.showSeconds = false,
  });

  final ClockStyle style;
  final ClockPosition position;

  /// Overrides the font family the [style] preset would otherwise imply.
  final ClockFont font;

  final int color; // ARGB
  final double sizePx; // 24–120
  final double opacity; // 0.0–1.0
  final bool showShadow;
  final bool showGlow;
  final bool showStroke;
  final bool is24Hour;
  final bool showDate;
  final bool showSeconds;

  ClockConfigEntity copyWith({
    ClockStyle? style,
    ClockPosition? position,
    ClockFont? font,
    int? color,
    double? sizePx,
    double? opacity,
    bool? showShadow,
    bool? showGlow,
    bool? showStroke,
    bool? is24Hour,
    bool? showDate,
    bool? showSeconds,
  }) {
    return ClockConfigEntity(
      style: style ?? this.style,
      position: position ?? this.position,
      font: font ?? this.font,
      color: color ?? this.color,
      sizePx: sizePx ?? this.sizePx,
      opacity: opacity ?? this.opacity,
      showShadow: showShadow ?? this.showShadow,
      showGlow: showGlow ?? this.showGlow,
      showStroke: showStroke ?? this.showStroke,
      is24Hour: is24Hour ?? this.is24Hour,
      showDate: showDate ?? this.showDate,
      showSeconds: showSeconds ?? this.showSeconds,
    );
  }

  @override
  List<Object?> get props => [
        style,
        position,
        font,
        color,
        sizePx,
        opacity,
        showShadow,
        showGlow,
        showStroke,
        is24Hour,
        showDate,
        showSeconds,
      ];
}
