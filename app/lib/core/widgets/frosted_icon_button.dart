import 'dart:ui';

import 'package:flutter/material.dart';

/// Circular frosted-glass icon button used over full-bleed images
/// (back, favorite, share on Wallpaper Details / Customize).
class FrostedIconButton extends StatelessWidget {
  const FrostedIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    this.iconColor = Colors.white,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? semanticLabel;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.black.withValues(alpha: 0.28),
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, color: iconColor, size: size * 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
