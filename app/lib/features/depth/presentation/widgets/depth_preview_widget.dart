import 'package:flutter/material.dart';

import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../explore/domain/entities/wallpaper_assets.dart';
import 'depth_layer_stack.dart';

/// Small layered depth preview card shown inside the Customize sheet.
///
/// Delegates the actual compositing to [DepthLayerStack] so the preview and the
/// full-screen render cannot drift apart - there is exactly one implementation
/// of the background -> clock -> foreground order.
class DepthPreviewWidget extends StatelessWidget {
  const DepthPreviewWidget({
    super.key,
    required this.backgroundUrl,
    required this.clockConfig,
    required this.depthEnabled,
    this.foregroundMaskUrl,
    this.depthConfig,
  });

  final String backgroundUrl;
  final ClockConfigEntity clockConfig;
  final bool depthEnabled;
  final String? foregroundMaskUrl;
  final DepthRenderConfig? depthConfig;

  @override
  Widget build(BuildContext context) {
    final showForeground = depthEnabled &&
        foregroundMaskUrl != null &&
        foregroundMaskUrl!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DepthLayerStack(
              backgroundUrl: backgroundUrl,
              foregroundUrl: showForeground ? foregroundMaskUrl : null,
              clockConfig: _previewConfig(),
              depthConfig: depthConfig,
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Center(
                child: Text(
                  'PREVIEW',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Scale the clock down for the small preview card. Only the size changes -
  // position, rotation and every other authored property render as configured,
  // so the preview stays a faithful miniature of the final composite.
  ClockConfigEntity _previewConfig() =>
      clockConfig.copyWith(sizePx: (clockConfig.sizePx * 0.5).clamp(20, 60));
}
