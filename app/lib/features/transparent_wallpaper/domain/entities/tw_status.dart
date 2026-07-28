import 'package:equatable/equatable.dart';

/// Every state the transparent wallpaper can be in, mirroring the native
/// `TransparentWallpaperManager.State`. The Flutter UI only reflects these — it
/// never computes them.
enum TwStatus {
  idle,
  checking,
  permissionNeeded,
  preparing,
  preview,
  applying,
  running,
  paused,
  stopped,
  error,
  cameraBusy,
  cameraLost,
  wallpaperRemoved,
  restoring,
  completed,
}

/// A snapshot of the native feature state.
class TwRuntimeState extends Equatable {
  const TwRuntimeState({
    required this.status,
    this.error,
    this.running = false,
    this.enabled = false,
  });

  final TwStatus status;
  final String? error;
  final bool running;
  final bool enabled;

  /// Terminal error states the UI should surface with a recovery action.
  bool get isError =>
      status == TwStatus.error ||
      status == TwStatus.cameraBusy ||
      status == TwStatus.cameraLost;

  static const idle = TwRuntimeState(status: TwStatus.idle);

  @override
  List<Object?> get props => [status, error, running, enabled];
}
