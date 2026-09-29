import '../../domain/entities/tw_status.dart';

/// Maps native state payloads (from `status` calls and the event stream) into
/// [TwRuntimeState]. Native sends the enum name lower-cased with underscores
/// (e.g. `camera_busy`).
class TwStatusModel {
  const TwStatusModel._();

  static TwRuntimeState fromMap(Map<dynamic, dynamic> map) {
    return TwRuntimeState(
      status: statusFrom(map['state'] as String?),
      error: map['error'] as String?,
      running: map['running'] as bool? ?? false,
      enabled: map['enabled'] as bool? ?? false,
      pendingApply: map['pendingApply'] as bool? ?? false,
    );
  }

  static TwStatus statusFrom(String? raw) {
    switch (raw) {
      case 'idle':
        return TwStatus.idle;
      case 'checking':
        return TwStatus.checking;
      case 'incompatible':
        return TwStatus.incompatible;
      case 'ready':
        return TwStatus.ready;
      case 'stopping':
        return TwStatus.stopping;
      case 'recovering':
        return TwStatus.recovering;
      case 'permission_needed':
        return TwStatus.permissionNeeded;
      case 'preparing':
        return TwStatus.preparing;
      case 'preview':
        return TwStatus.preview;
      case 'applying':
        return TwStatus.applying;
      case 'running':
        return TwStatus.running;
      case 'paused':
        return TwStatus.paused;
      case 'stopped':
        return TwStatus.stopped;
      case 'error':
        return TwStatus.error;
      case 'camera_busy':
        return TwStatus.cameraBusy;
      case 'camera_lost':
        return TwStatus.cameraLost;
      case 'wallpaper_removed':
        return TwStatus.wallpaperRemoved;
      case 'restoring':
        return TwStatus.restoring;
      case 'completed':
        return TwStatus.completed;
      default:
        return TwStatus.idle;
    }
  }
}
