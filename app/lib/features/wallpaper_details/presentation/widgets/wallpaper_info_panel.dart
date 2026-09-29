import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../../../explore/domain/entities/wallpaper_type.dart';

/// Frosted glass info panel pinned to the bottom of Wallpaper Details,
/// floating over the full-bleed wallpaper image. Shows the title, category ·
/// resolution, and the approved white/black Apply CTA - a Live wallpaper
/// additionally gets a Play/Pause control beside it.
class WallpaperInfoPanel extends StatelessWidget {
  const WallpaperInfoPanel({
    super.key,
    required this.wallpaper,
    required this.onApply,
    this.isPlaying,
    this.onPlayPauseToggle,
  });

  final WallpaperEntity wallpaper;
  final VoidCallback onApply;

  /// Live wallpaper only: current playback state, driving the Play/Pause
  /// icon. Null (normal/depth wallpapers) hides the control entirely.
  final bool? isPlaying;
  final VoidCallback? onPlayPauseToggle;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.only(
      topLeft: Radius.circular(28),
      topRight: Radius.circular(28),
    );
    // Keep the CTAs above the gesture/nav bar on every device (edge-to-edge).
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return DecoratedBox(
      // Soft shadow lifting the glass off the wallpaper.
      decoration: const BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 30,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, 22, 24, 18 + bottomInset),
            decoration: BoxDecoration(
              // Liquid-glass: translucent so the wallpaper shows through.
              color: const Color(0xFF141922).withValues(alpha: 0.42),
              borderRadius: radius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallpaper.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${wallpaper.category.displayName(context.languageCode)}'
                  '  ·  ${wallpaper.resolution}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (wallpaper.type == WallpaperType.live &&
                        isPlaying != null) ...[
                      _PlayPauseButton(
                        isPlaying: isPlaying!,
                        onTap: onPlayPauseToggle,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: _PanelButton(
                        label: context.l10n.apply,
                        onTap: onApply,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The approved Apply CTA: white pill, black text - never the dark/black
/// button an earlier pass on this panel used.
class _PanelButton extends StatelessWidget {
  const _PanelButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppShapes.pill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppShapes.pill,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyLarge.copyWith(color: Colors.black),
          ),
        ),
      ),
    );
  }
}

/// Compact circular Play/Pause control, placed beside Apply for a Live
/// wallpaper - never overlaid on the video itself.
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.isPlaying, required this.onTap});

  final bool isPlaying;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isPlaying ? 'Pause' : 'Play',
      child: Material(
        color: Colors.white24,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
