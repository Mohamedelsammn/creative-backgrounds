import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/clock_config_entity.dart';
import '../../domain/usecases/load_clock_config_usecase.dart';
import '../../domain/usecases/save_clock_config_usecase.dart';

part 'clock_event.dart';
part 'clock_state.dart';

class ClockBloc extends Bloc<ClockEvent, ClockState> {
  ClockBloc({
    required LoadClockConfigUseCase load,
    required SaveClockConfigUseCase save,
  })  : _load = load,
        _save = save,
        super(const ClockInitial()) {
    on<ClockConfigLoaded>(_onLoad);
    on<ClockPositionChanged>((e, emit) => _update(emit, (c) => c.copyWith(position: e.position)));
    on<ClockFontChanged>((e, emit) => _update(emit, (c) => c.copyWith(font: e.font)));
    on<ClockColorChanged>((e, emit) => _update(emit, (c) => c.copyWith(color: e.color)));
    on<ClockSizeChanged>((e, emit) => _update(emit, (c) => c.copyWith(sizePx: e.size)));
    on<ClockOpacityChanged>((e, emit) => _update(emit, (c) => c.copyWith(opacity: e.opacity)));
    on<ClockShadowToggled>((e, emit) => _update(emit, (c) => c.copyWith(showShadow: e.enabled)));
    on<ClockGlowToggled>((e, emit) => _update(emit, (c) => c.copyWith(showGlow: e.enabled)));
    on<ClockStrokeToggled>((e, emit) => _update(emit, (c) => c.copyWith(showStroke: e.enabled)));
    on<ClockHourFormatChanged>((e, emit) => _update(emit, (c) => c.copyWith(is24Hour: e.is24Hour)));
    on<ClockDateToggled>((e, emit) => _update(emit, (c) => c.copyWith(showDate: e.enabled)));
    on<ClockSecondsToggled>((e, emit) => _update(emit, (c) => c.copyWith(showSeconds: e.enabled)));
    on<ClockStyleChanged>(_onStyleChanged);
    on<ClockConfigSaved>(_onSaved);
  }

  final LoadClockConfigUseCase _load;
  final SaveClockConfigUseCase _save;

  ClockConfigEntity get config =>
      state is ClockReady ? (state as ClockReady).config : const ClockConfigEntity();

  Future<void> _onLoad(ClockConfigLoaded event, Emitter<ClockState> emit) async {
    final config = await _load();
    emit(ClockReady(config));
  }

  void _update(
    Emitter<ClockState> emit,
    ClockConfigEntity Function(ClockConfigEntity) mutate,
  ) {
    emit(ClockReady(mutate(config)));
  }

  /// Selecting a style seeds the font (the style's implied family) as a starting
  /// point; the Font chips can still override the family independently.
  void _onStyleChanged(ClockStyleChanged event, Emitter<ClockState> emit) {
    final font = switch (event.style) {
      ClockStyle.modern => ClockFont.inter,
      ClockStyle.minimal => ClockFont.inter,
      ClockStyle.elegant => ClockFont.serif,
      ClockStyle.digital => ClockFont.mono,
    };
    emit(ClockReady(config.copyWith(style: event.style, font: font)));
  }

  Future<void> _onSaved(ClockConfigSaved event, Emitter<ClockState> emit) async {
    final current = config;
    emit(const ClockSaving());
    await _save(current);
    emit(ClockReady(current));
  }
}
