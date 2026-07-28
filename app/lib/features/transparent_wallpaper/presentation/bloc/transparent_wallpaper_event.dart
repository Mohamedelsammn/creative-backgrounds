part of 'transparent_wallpaper_bloc.dart';

sealed class TransparentWallpaperEvent extends Equatable {
  const TransparentWallpaperEvent();

  @override
  List<Object?> get props => [];
}

/// Load compatibility + permissions and subscribe to native status.
class TransparentWallpaperStarted extends TransparentWallpaperEvent {
  const TransparentWallpaperStarted();
}

/// Prompt for camera / notification permissions.
class TransparentPermissionsRequested extends TransparentWallpaperEvent {
  const TransparentPermissionsRequested();
}

/// Begin the apply flow (start foreground service + open live picker).
class TransparentActivationRequested extends TransparentWallpaperEvent {
  const TransparentActivationRequested();
}

/// Stop the feature and restore the previous wallpaper.
class TransparentDeactivationRequested extends TransparentWallpaperEvent {
  const TransparentDeactivationRequested();
}

/// Open the system app-settings page (permanently-denied recovery).
class TransparentSettingsRequested extends TransparentWallpaperEvent {
  const TransparentSettingsRequested();
}

/// The user accepted the camera prominent disclosure (persist it).
class TransparentDisclosureAccepted extends TransparentWallpaperEvent {
  const TransparentDisclosureAccepted();
}

/// Open battery-optimization settings (OEM background-kill mitigation).
class TransparentBatterySettingsRequested extends TransparentWallpaperEvent {
  const TransparentBatterySettingsRequested();
}

/// Change the target FPS / quality preset.
class TransparentFpsChanged extends TransparentWallpaperEvent {
  const TransparentFpsChanged(this.fps);

  final int fps;

  @override
  List<Object?> get props => [fps];
}

/// Restore the previously-set wallpaper without changing anything else.
class TransparentRestoreRequested extends TransparentWallpaperEvent {
  const TransparentRestoreRequested();
}

/// Internal: a native state change arrived on the status stream.
class TransparentStatusChanged extends TransparentWallpaperEvent {
  const TransparentStatusChanged(this.runtime);

  final TwRuntimeState runtime;

  @override
  List<Object?> get props => [runtime];
}
