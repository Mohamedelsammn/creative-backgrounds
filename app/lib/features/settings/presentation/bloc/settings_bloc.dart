import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/usecases/get_settings_usecase.dart';
import '../../domain/usecases/update_settings_usecase.dart';

part 'settings_event.dart';
part 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({
    required GetSettingsUseCase getSettings,
    required UpdateSettingsUseCase updateSettings,
  })  : _getSettings = getSettings,
        _updateSettings = updateSettings,
        super(const SettingsInitial()) {
    on<SettingsLoadRequested>(_onLoad);
    on<SettingsLanguageChanged>(_onLanguageChanged);
    on<SettingsClearCacheRequested>(_onClearCache);
  }

  final GetSettingsUseCase _getSettings;
  final UpdateSettingsUseCase _updateSettings;

  Future<void> _onLoad(
    SettingsLoadRequested event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());
    final result = await _getSettings(const NoParams());
    result.fold(
      (f) => emit(SettingsError(f.message)),
      (settings) => emit(SettingsLoaded(settings)),
    );
  }

  Future<void> _onLanguageChanged(
    SettingsLanguageChanged event,
    Emitter<SettingsState> emit,
  ) async {
    await _apply(
      emit,
      UpdateSettingsParams(SettingsUpdate.language,
          stringValue: event.language),
    );
  }

  Future<void> _onClearCache(
    SettingsClearCacheRequested event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsCacheClearing());
    await _apply(
      emit,
      const UpdateSettingsParams(SettingsUpdate.clearCache),
    );
  }

  Future<void> _apply(
    Emitter<SettingsState> emit,
    UpdateSettingsParams params,
  ) async {
    final result = await _updateSettings(params);
    result.fold(
      (f) => emit(SettingsError(f.message)),
      (settings) => emit(SettingsLoaded(settings)),
    );
  }
}
