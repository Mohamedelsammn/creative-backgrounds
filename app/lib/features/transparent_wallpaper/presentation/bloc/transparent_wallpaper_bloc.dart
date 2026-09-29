import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/compatibility_report.dart';
import '../../domain/entities/tw_permissions.dart';
import '../../domain/entities/tw_settings.dart';
import '../../domain/entities/tw_status.dart';
import '../../domain/repositories/transparent_wallpaper_repository.dart';
import '../../domain/usecases/check_compatibility_usecase.dart';
import '../../domain/usecases/request_permissions_usecase.dart';
import '../../domain/usecases/start_transparent_wallpaper_usecase.dart';
import '../../domain/usecases/stop_transparent_wallpaper_usecase.dart';

part 'transparent_wallpaper_event.dart';
part 'transparent_wallpaper_state.dart';

/// Drives the transparent-wallpaper control surface (Explore card, preview,
/// settings). Native remains the source of truth: this bloc queries
/// compatibility/permissions once and then mirrors the live status stream.
/// A single, app-wide bloc: the transparent wallpaper is one device feature
/// with one state, observed from several screens.
///
/// Also watches the app lifecycle. Returning to the foreground is the moment
/// the outcome of the system wallpaper picker becomes knowable, and the moment
/// a permission granted in Settings takes effect - so both are re-read then.
class TransparentWallpaperBloc
    extends Bloc<TransparentWallpaperEvent, TransparentWallpaperState>
    with WidgetsBindingObserver {
  TransparentWallpaperBloc({
    required CheckCompatibilityUseCase checkCompatibility,
    required RequestPermissionsUseCase requestPermissions,
    required StartTransparentWallpaperUseCase start,
    required StopTransparentWallpaperUseCase stop,
    required TransparentWallpaperRepository repository,
  })  : _checkCompatibility = checkCompatibility,
        _requestPermissions = requestPermissions,
        _start = start,
        _stop = stop,
        _repository = repository,
        super(const TransparentWallpaperState()) {
    on<TransparentWallpaperStarted>(_onStarted);
    on<TransparentPermissionsRequested>(_onRequestPermissions);
    on<TransparentActivationRequested>(_onActivate);
    on<TransparentDeactivationRequested>(_onDeactivate);
    on<TransparentSettingsRequested>(_onOpenSettings);
    on<TransparentBatterySettingsRequested>(_onOpenBatterySettings);
    on<TransparentDisclosureAccepted>(_onDisclosureAccepted);
    on<TransparentFpsChanged>(_onFpsChanged);
    on<TransparentRestoreRequested>(_onRestore);
    on<TransparentStatusChanged>(_onStatusChanged);
    on<TransparentResumed>(_onResumed);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) add(const TransparentResumed());
  }

  final CheckCompatibilityUseCase _checkCompatibility;
  final RequestPermissionsUseCase _requestPermissions;
  final StartTransparentWallpaperUseCase _start;
  final StopTransparentWallpaperUseCase _stop;
  final TransparentWallpaperRepository _repository;

  StreamSubscription<TwRuntimeState>? _statusSub;

  /// Guards against the several screens that each fire [TransparentWallpaperStarted]
  /// on build re-running the whole probe and re-subscribing every time.
  bool _initialized = false;

  Future<void> _onStarted(
    TransparentWallpaperStarted event,
    Emitter<TransparentWallpaperState> emit,
  ) async {
    // Several surfaces provide this bloc and each fires Started on build. The
    // first one does the work; the rest simply attach to the state it produced.
    if (_initialized) return;
    _initialized = true;
    emit(state.copyWith(phase: TwViewPhase.loading));

    final compatResult = await _checkCompatibility(const NoParams());
    final compat = compatResult.fold((_) => null, (r) => r);

    final permissions = await _repository.getPermissionStatus();
    final perms = permissions.fold((_) => null, (p) => p);

    final statusResult = await _repository.status();
    final runtime = statusResult.fold((_) => TwRuntimeState.idle, (s) => s);

    final settingsResult = await _repository.getSettings();
    final settings = settingsResult.fold((_) => const TwSettings(), (s) => s);

    emit(state.copyWith(
      phase: TwViewPhase.ready,
      compatibility: compat,
      permissions: perms,
      runtime: runtime,
      disclosureAccepted: _repository.isDisclosureAccepted(),
      settings: settings,
    ));

    // Mirror native state changes for the lifetime of the bloc.
    await _statusSub?.cancel();
    _statusSub = _repository.watchStatus().listen(
          (rt) => add(TransparentStatusChanged(rt)),
        );
  }

  Future<void> _onRequestPermissions(
    TransparentPermissionsRequested event,
    Emitter<TransparentWallpaperState> emit,
  ) async {
    emit(state.copyWith(busy: true));
    final result = await _requestPermissions(const NoParams());
    result.fold(
      (_) => emit(state.copyWith(busy: false)),
      (perms) => emit(state.copyWith(busy: false, permissions: perms)),
    );
  }

  Future<void> _onActivate(
    TransparentActivationRequested event,
    Emitter<TransparentWallpaperState> emit,
  ) async {
    emit(state.copyWith(busy: true));
    final result = await _start(const NoParams());
    result.fold(
      (failure) => emit(state.copyWith(busy: false, errorMessage: failure.message)),
      (_) => emit(state.copyWith(busy: false)),
    );
    // Progression to RUNNING arrives via the status stream.
  }

  Future<void> _onDeactivate(
    TransparentDeactivationRequested event,
    Emitter<TransparentWallpaperState> emit,
  ) async {
    emit(state.copyWith(busy: true));
    final result = await _stop(const NoParams());
    result.fold(
      (failure) => emit(state.copyWith(busy: false, errorMessage: failure.message)),
      (_) => emit(state.copyWith(busy: false)),
    );
  }

  Future<void> _onOpenSettings(
    TransparentSettingsRequested event,
    Emitter<TransparentWallpaperState> emit,
  ) async {
    await _repository.openAppSettings();
  }

  Future<void> _onOpenBatterySettings(
    TransparentBatterySettingsRequested event,
    Emitter<TransparentWallpaperState> emit,
  ) async {
    await _repository.openBatterySettings();
  }

  Future<void> _onDisclosureAccepted(
    TransparentDisclosureAccepted event,
    Emitter<TransparentWallpaperState> emit,
  ) async {
    await _repository.setDisclosureAccepted();
    emit(state.copyWith(disclosureAccepted: true));
  }

  Future<void> _onFpsChanged(
    TransparentFpsChanged event,
    Emitter<TransparentWallpaperState> emit,
  ) async {
    final next = state.settings.copyWith(fps: event.fps);
    emit(state.copyWith(settings: next));
    await _repository.updateSettings(next);
  }

  Future<void> _onRestore(
    TransparentRestoreRequested event,
    Emitter<TransparentWallpaperState> emit,
  ) async {
    emit(state.copyWith(busy: true));
    await _repository.restorePreviousWallpaper();
    emit(state.copyWith(busy: false));
  }

  /// Re-reads everything that can change while the app is backgrounded: the
  /// picker's outcome, a permission granted in Settings, and whether the
  /// wallpaper is still ours.
  Future<void> _onResumed(
    TransparentResumed event,
    Emitter<TransparentWallpaperState> emit,
  ) async {
    if (!_initialized) return;

    final runtime = await _repository.syncWithSystem();
    final permissions = await _repository.getPermissionStatus();

    emit(state.copyWith(
      runtime: runtime.fold((_) => state.runtime, (r) => r),
      permissions: permissions.fold((_) => state.permissions, (p) => p),
      // A resume always resolves any in-flight request: whatever the native
      // side reports now is the truth, so the UI must never stay "busy".
      busy: false,
    ));
  }

  void _onStatusChanged(
    TransparentStatusChanged event,
    Emitter<TransparentWallpaperState> emit,
  ) {
    emit(state.copyWith(runtime: event.runtime));
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _statusSub?.cancel();
    return super.close();
  }
}
