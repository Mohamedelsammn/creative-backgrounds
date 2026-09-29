import 'package:flutter/material.dart';

import '../../features/explore/domain/entities/wallpaper_type.dart';
import '../theme/app_text_styles.dart';

/// Small frosted pill marking a wallpaper that is more than a flat image.
///
/// Only shown for [WallpaperType.depth] and [WallpaperType.live] - a normal
/// wallpaper needs no marker, and an unknown type is not advertised as
/// something the user can use. Deliberately mirrors [ProBadge]'s geometry so
/// the two read as one family when both appear on a card.
class WallpaperTypeBadge extends StatelessWidget {
  const WallpaperTypeBadge({super.key, required this.type, this.durationMs});

  final WallpaperType type;

  /// The clip's length, for [WallpaperType.live] - shown as its running time
  /// (e.g. "0:10") instead of the generic "LIVE" label when known, since the
  /// actual duration tells the user more than a static badge does. Null (the
  /// feed's list rows never carry it) falls back to "LIVE".
  final int? durationMs;

  /// Whether this type is worth marking at all.
  static bool showsFor(WallpaperType type) =>
      type == WallpaperType.depth || type == WallpaperType.live;

  static String _formatDuration(int ms) {
    final totalSeconds = (ms / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final liveLabel =
        durationMs != null ? _formatDuration(durationMs!) : 'LIVE';
    final (label, icon) = switch (type) {
      WallpaperType.depth => ('DEPTH', Icons.layers_outlined),
      WallpaperType.live => (liveLabel, Icons.play_circle_outline),
      _ => ('', null),
    };
    if (label.isEmpty) return const SizedBox.shrink();

    final semanticLabel = switch (type) {
      WallpaperType.live => durationMs != null
          ? 'Live wallpaper, $label long'
          : 'Live wallpaper',
      _ => '$label wallpaper',
    };

    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
