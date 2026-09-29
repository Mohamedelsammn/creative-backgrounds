import 'package:flutter/widgets.dart';

import '../../../../core/l10n/l10n.dart';
import '../../domain/entities/tw_status.dart';

/// Maps a runtime status to a localized, human-readable sentence. Returns null
/// for states that need no explanatory line (idle / checking / preview /
/// permissionNeeded — those are handled by dedicated UI).
String? twStatusMessage(BuildContext context, TwRuntimeState runtime) {
  final l10n = context.l10n;
  switch (runtime.status) {
    case TwStatus.running:
      return l10n.twMsgRunning;
    case TwStatus.preparing:
      return l10n.twMsgPreparing;
    case TwStatus.applying:
      return l10n.twMsgApplying;
    case TwStatus.restoring:
      return l10n.twMsgRestoring;
    case TwStatus.stopping:
      return l10n.twMsgStopping;
    case TwStatus.recovering:
      return l10n.twMsgRecovering;
    case TwStatus.incompatible:
      return l10n.twMsgIncompatible;
    case TwStatus.paused:
      return l10n.twMsgPaused;
    case TwStatus.stopped:
    case TwStatus.completed:
      return l10n.twMsgStopped;
    case TwStatus.cameraBusy:
      return l10n.twMsgCameraBusy;
    case TwStatus.cameraLost:
      return l10n.twMsgCameraLost;
    case TwStatus.wallpaperRemoved:
      return l10n.twMsgWallpaperRemoved;
    case TwStatus.error:
      return runtime.error?.isNotEmpty == true
          ? runtime.error
          : l10n.twMsgError;
    case TwStatus.idle:
    case TwStatus.checking:
    case TwStatus.permissionNeeded:
    case TwStatus.preview:
    // Handled by dedicated UI rather than an explanatory line.
    case TwStatus.ready:
      return null;
  }
}
