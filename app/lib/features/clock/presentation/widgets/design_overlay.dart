import 'package:flutter/material.dart';

import '../../domain/entities/studio_design_entity.dart';
import 'battery_ring_widget.dart';
import 'clock_renderer_widget.dart';
import 'date_widget_renderer.dart';

/// Renders a dashboard-authored [StudioDesign] on top of whatever media is
/// already painted beneath it.
///
/// This is the ONE Flutter-side composition of an authored design, used by
/// Details for every media type (static, video and depth alike) so a design
/// cannot look different depending on which screen or which wallpaper type is
/// showing it. The media itself is never drawn here - this only paints the
/// authored elements over it.
///
/// Deliberately NOT used in feed/Home cards: composing a live clock per card
/// would put a ticking timer behind every tile. Cards keep showing their
/// thumbnail (or the server-rendered `styledPreviewUrl` where one exists).
/// Which layers of a design to draw. DEPTH composes the clock and the
/// extras (date widget, widgets) at different depths - see
/// `DepthLiveComposition`.
enum DesignOverlayPart { all, clockOnly, extrasOnly }

class DesignOverlay extends StatelessWidget {
  const DesignOverlay({
    super.key,
    required this.design,
    this.displayScale = 1.0,
    this.clockLocale,
    this.drawClockAndDate = true,
    this.drawWidgets = true,
    this.part = DesignOverlayPart.all,
  });

  final DesignOverlayPart part;

  final StudioDesign design;

  /// Forwarded to [ClockRendererWidget.displayScale]: identity for a full-size
  /// render, less than 1.0 for a smaller preview box. Authored sizes are in
  /// logical pixels against a full screen, so a preview that is only a
  /// fraction of the screen must scale them down by the same fraction or the
  /// clock looks far larger in the preview than once applied.
  final double displayScale;

  final String? clockLocale;

  /// Whether the clock and the independent date widget should actually be
  /// drawn here.
  ///
  /// False when the image already painted beneath this overlay has them
  /// baked in - see [WallpaperEntity.resolveDetailsVisual]. Defaults to
  /// `true` so every other caller (the live-wallpaper apply path, which
  /// always composes against a bare surface) is unaffected.
  final bool drawClockAndDate;

  /// Whether studio widgets (`batteryRing`) should be drawn here. A widget
  /// reads live device state, so unlike the clock/date it is never baked
  /// into any backend asset - this exists for symmetry and future widget
  /// kinds, not because any known one needs suppressing.
  final bool drawWidgets;

  @override
  Widget build(BuildContext context) {
    final clock = design.clock;
    final widgets = design.widgets;

    final dateWidget = design.dateWidget;
    final clockLayer = part != DesignOverlayPart.extrasOnly;
    final extrasLayer = part != DesignOverlayPart.clockOnly;
    final showClock = clockLayer && drawClockAndDate && (clock?.enabled ?? false);
    final showDate = extrasLayer && drawClockAndDate && (dateWidget?.enabled ?? false);
    final showWidgets = extrasLayer && drawWidgets && widgets.isNotEmpty;

    // Nothing left to paint: either nothing was authored, or everything that
    // was is already baked into the image beneath this overlay.
    if (!showClock && !showDate && !showWidgets) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showClock)
            ClockRendererWidget(
              config: clock!,
              locale: clockLocale,
              displayScale: displayScale,
            ),
          // The independently-positioned date element. Distinct from the
          // clock's own nested `date`, which `ClockRendererWidget` draws.
          if (showDate)
            DateWidgetRenderer(
              config: dateWidget!,
              now: DateTime.now(),
              displayScale: displayScale,
            ),
          // Widgets paint above the clock, matching the authoring order: the
          // clock is the base element and widgets are placed on top of it.
          if (showWidgets)
            for (final widget in widgets) _widget(widget),
        ],
      ),
    );
  }

  Widget _widget(StudioWidget widget) => switch (widget) {
    StudioBatteryRing() => BatteryRingWidget(
      config: widget,
      displayScale: displayScale,
    ),
  };
}
