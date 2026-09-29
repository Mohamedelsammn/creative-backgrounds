import 'package:equatable/equatable.dart';

/// Every state the transparent wallpaper can be in, mirroring the native
/// `TransparentWallpaperManager.State`. The Flutter UI only reflects these — it
/// never computes them.
enum TwStatus {
  idle,
  checking,

  /// The device cannot run the feature at all.
  incompatible,

  permissionNeeded,

  /// Compatible and permitted; waiting for the user to start.
  ready,

  preparing,
  preview,
  applying,
  running,
  paused,

  /// Tearing down after the user disabled the feature.
  stopping,

  restoring,
  stopped,

  /// A transient camera failure; a retry is scheduled.
  recovering,

  error,
  cameraBusy,
  cameraLost,
  wallpaperRemoved,
  completed,
}

/// A snapshot of the native feature state.
class TwRuntimeState extends Equatable {
  const TwRuntimeState({
    required this.status,
    this.error,
    this.running = false,
    this.enabled = false,
    this.pendingApply = false,
  });

  final TwStatus status;
  final String? error;
  final bool running;

  /// The user's durable intent: this wallpaper is their wallpaper.
  final bool enabled;

  /// The system picker is open and the outcome is not yet known. Distinct from
  /// [enabled] so cancelling the picker cannot leave the feature stuck "on".
  final bool pendingApply;

  /// Terminal error states the UI should surface with a recovery action.
  bool get isError =>
      status == TwStatus.error ||
      status == TwStatus.cameraBusy ||
      status == TwStatus.cameraLost;

  /// Work is in flight and the user should see progress, not a result.
  bool get isBusy =>
      status == TwStatus.preparing ||
      status == TwStatus.applying ||
      status == TwStatus.stopping ||
      status == TwStatus.restoring ||
      pendingApply;

  /// The wallpaper is set, whether or not it is on screen this instant.
  bool get isActive =>
      enabled ||
      status == TwStatus.running ||
      status == TwStatus.paused ||
      status == TwStatus.recovering;

  static const idle = TwRuntimeState(status: TwStatus.idle);

  @override
  List<Object?> get props => [status, error, running, enabled, pendingApply];
}
