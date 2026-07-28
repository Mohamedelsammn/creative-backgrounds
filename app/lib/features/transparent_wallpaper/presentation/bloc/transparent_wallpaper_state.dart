part of 'transparent_wallpaper_bloc.dart';

/// High-level UI phase while the control surface loads native data.
enum TwViewPhase { loading, ready }

class TransparentWallpaperState extends Equatable {
  const TransparentWallpaperState({
    this.phase = TwViewPhase.loading,
    this.compatibility,
    this.permissions,
    this.runtime = TwRuntimeState.idle,
    this.busy = false,
    this.errorMessage,
    this.disclosureAccepted = false,
    this.settings = const TwSettings(),
  });

  final TwViewPhase phase;
  final CompatibilityReport? compatibility;
  final TwPermissions? permissions;
  final TwRuntimeState runtime;
  final bool busy;
  final String? errorMessage;
  final bool disclosureAccepted;
  final TwSettings settings;

  /// Device can run the feature at all.
  bool get isSupported => compatibility?.isUsable ?? false;

  /// The wallpaper is currently active/running.
  bool get isActive =>
      runtime.running ||
      runtime.status == TwStatus.running ||
      runtime.enabled;

  /// Camera permission has been granted.
  bool get cameraGranted => permissions?.isReady ?? false;

  TransparentWallpaperState copyWith({
    TwViewPhase? phase,
    CompatibilityReport? compatibility,
    TwPermissions? permissions,
    TwRuntimeState? runtime,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
    bool? disclosureAccepted,
    TwSettings? settings,
  }) {
    return TransparentWallpaperState(
      phase: phase ?? this.phase,
      compatibility: compatibility ?? this.compatibility,
      permissions: permissions ?? this.permissions,
      runtime: runtime ?? this.runtime,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      disclosureAccepted: disclosureAccepted ?? this.disclosureAccepted,
      settings: settings ?? this.settings,
    );
  }

  @override
  List<Object?> get props => [
        phase,
        compatibility,
        permissions,
        runtime,
        busy,
        errorMessage,
        disclosureAccepted,
        settings,
      ];
}
