import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_shapes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';

/// Frosted dark info panel pinned to the bottom of Wallpaper Details.
/// Shows the title, category · resolution, and Customize / Apply CTAs.
class WallpaperInfoPanel extends StatelessWidget {
  const WallpaperInfoPanel({
    super.key,
    required this.wallpaper,
    required this.onCustomize,
    required this.onApply,
  });

  final WallpaperEntity wallpaper;
  final VoidCallback onCustomize;
  final VoidCallback onApply;

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
          BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, -6)),
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
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${wallpaper.category.name}  ·  ${wallpaper.resolution}',
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _PanelButton(
                      label: 'Customize',
                      icon: Icons.auto_awesome,
                      filled: true,
                      onTap: onCustomize,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PanelButton(
                      label: 'Apply',
                      dark: true,
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

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = false,
    this.dark = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool filled;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? Colors.black : (filled ? Colors.white : Colors.white24);
    final fg = dark ? Colors.white : Colors.black;
    return Material(
      color: bg,
      borderRadius: AppShapes.pill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppShapes.pill,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: AppTextStyles.bodyLarge.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
