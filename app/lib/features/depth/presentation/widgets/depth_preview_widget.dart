import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../clock/presentation/widgets/clock_renderer_widget.dart';

/// Layered depth preview card: background → clock → foreground mask.
/// When depth is off or no mask exists, the clock simply renders on top.
class DepthPreviewWidget extends StatelessWidget {
  const DepthPreviewWidget({
    super.key,
    required this.backgroundUrl,
    required this.clockConfig,
    required this.depthEnabled,
    this.foregroundMaskUrl,
  });

  final String backgroundUrl;
  final ClockConfigEntity clockConfig;
  final bool depthEnabled;
  final String? foregroundMaskUrl;

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
            CachedNetworkImage(
              imageUrl: backgroundUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Container(color: const Color(0xFF15151A)),
              errorWidget: (context, url, error) =>
                  Container(color: const Color(0xFF15151A)),
            ),
            // Clock layer (scaled down for the small preview).
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.none,
                child: SizedBox(
                  width: 360,
                  height: 220,
                  child: ClockRendererWidget(config: _previewConfig()),
                ),
              ),
            ),
            if (showForeground)
              CachedNetworkImage(
                imageUrl: foregroundMaskUrl!,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const SizedBox.shrink(),
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

  // Scale the clock down for the small preview card.
  ClockConfigEntity _previewConfig() =>
      clockConfig.copyWith(sizePx: (clockConfig.sizePx * 0.5).clamp(20, 60));
}
