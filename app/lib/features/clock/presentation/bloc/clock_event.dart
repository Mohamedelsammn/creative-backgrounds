part of 'clock_bloc.dart';

sealed class ClockEvent extends Equatable {
  const ClockEvent();

  @override
  List<Object?> get props => [];
}

class ClockConfigLoaded extends ClockEvent {
  const ClockConfigLoaded();
}

class ClockPositionChanged extends ClockEvent {
  const ClockPositionChanged(this.position);
  final ClockPosition position;
  @override
  List<Object?> get props => [position];
}

class ClockFontChanged extends ClockEvent {
  const ClockFontChanged(this.font);
  final ClockFont font;
  @override
  List<Object?> get props => [font];
}

class ClockColorChanged extends ClockEvent {
  const ClockColorChanged(this.color);
  final int color;
  @override
  List<Object?> get props => [color];
}

class ClockSizeChanged extends ClockEvent {
  const ClockSizeChanged(this.size);
  final double size;
  @override
  List<Object?> get props => [size];
}

class ClockOpacityChanged extends ClockEvent {
  const ClockOpacityChanged(this.opacity);
  final double opacity;
  @override
  List<Object?> get props => [opacity];
}

class ClockShadowToggled extends ClockEvent {
  const ClockShadowToggled(this.enabled);
  final bool enabled;
  @override
  List<Object?> get props => [enabled];
}

class ClockGlowToggled extends ClockEvent {
  const ClockGlowToggled(this.enabled);
  final bool enabled;
  @override
  List<Object?> get props => [enabled];
}

class ClockStrokeToggled extends ClockEvent {
  const ClockStrokeToggled(this.enabled);
  final bool enabled;
  @override
  List<Object?> get props => [enabled];
}

class ClockHourFormatChanged extends ClockEvent {
  const ClockHourFormatChanged(this.is24Hour);
  final bool is24Hour;
  @override
  List<Object?> get props => [is24Hour];
}

class ClockDateToggled extends ClockEvent {
  const ClockDateToggled(this.enabled);
  final bool enabled;
  @override
  List<Object?> get props => [enabled];
}

class ClockSecondsToggled extends ClockEvent {
  const ClockSecondsToggled(this.enabled);
  final bool enabled;
  @override
  List<Object?> get props => [enabled];
}

class ClockStyleChanged extends ClockEvent {
  const ClockStyleChanged(this.style);
  final ClockStyle style;
  @override
  List<Object?> get props => [style];
}

class ClockConfigSaved extends ClockEvent {
  const ClockConfigSaved();
}
