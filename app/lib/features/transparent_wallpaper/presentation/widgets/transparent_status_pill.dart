import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../domain/entities/tw_status.dart';
import '../bloc/transparent_wallpaper_bloc.dart';

/// Small colored pill summarizing the current transparent-wallpaper status,
/// derived from the bloc state (support + permission + runtime).
class TransparentStatusPill extends StatelessWidget {
  const TransparentStatusPill({super.key, required this.state});

  final TransparentWallpaperState state;

  @override
  Widget build(BuildContext context) {
    final descriptor = _describe(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: descriptor.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: descriptor.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            descriptor.label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: descriptor.color,
            ),
          ),
        ],
      ),
    );
  }

  _PillDescriptor _describe(BuildContext context) {
    final l10n = context.l10n;
    const green = Color(0xFF34C759);
    const amber = Color(0xFFFF9500);
    const red = Color(0xFFFF3B30);
    const gray = Color(0xFF8E8E93);

    if (!state.isSupported) {
      return _PillDescriptor(l10n.twStatusUnsupported, gray);
    }
    switch (state.runtime.status) {
      case TwStatus.running:
        return _PillDescriptor(l10n.twStatusActive, green);
      case TwStatus.preparing:
      case TwStatus.applying:
      case TwStatus.restoring:
      case TwStatus.checking:
        return _PillDescriptor(l10n.twStatusPreparing, amber);
      case TwStatus.error:
      case TwStatus.cameraBusy:
      case TwStatus.cameraLost:
      case TwStatus.wallpaperRemoved:
        return _PillDescriptor(l10n.twStatusNeedsAttention, red);
      case TwStatus.permissionNeeded:
        return _PillDescriptor(l10n.twStatusPermissionNeeded, amber);
      default:
        if (state.isActive) return _PillDescriptor(l10n.twStatusActive, green);
        if (!state.cameraGranted) {
          return _PillDescriptor(l10n.twStatusPermissionNeeded, amber);
        }
        return _PillDescriptor(l10n.twStatusInactive, gray);
    }
  }
}

class _PillDescriptor {
  const _PillDescriptor(this.label, this.color);
  final String label;
  final Color color;
}
