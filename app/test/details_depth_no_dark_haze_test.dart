import 'package:cached_network_image/cached_network_image.dart';
import 'package:creativebackground/features/clock/domain/entities/clock_config_entity.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:creativebackground/features/clock/presentation/widgets/clock_renderer_widget.dart';
import 'package:creativebackground/features/depth/presentation/widgets/depth_live_composition.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression: DEPTH Details showed a dark horizontal haze over the artwork
/// (production wallpaper "catch": foregroundOffsetY 0.195, shadowStrength
/// 0.35). The foreground was wrapped in a BoxShadow, which shades the image's
/// whole rectangle - so the shifted foreground box darkened everything from
/// 19.5% of the height down. The applied wallpaper draws no such shadow.
void main() {
  const fg = 'https://cdn.test/catch-fg.webp';
  const bg = 'https://cdn.test/catch-bg.webp';

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 400,
          height: 860,
          child: DepthLiveComposition(
            backgroundUrl: bg,
            foregroundUrl: fg,
            design: StudioDesign(clock: ClockConfigEntity(enabled: true)),
            depthConfig: DepthRenderConfig(foregroundOffsetY: 0.195, shadowStrength: 0.35),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('no box-shaped shadow or dark scrim is painted over the artwork', (tester) async {
    await pump(tester);
    final decorated = tester.widgetList<DecoratedBox>(
      find.descendant(of: find.byType(DepthLiveComposition), matching: find.byType(DecoratedBox)),
    );
    for (final d in decorated) {
      final deco = d.decoration;
      if (deco is BoxDecoration) {
        expect(deco.boxShadow, isNull, reason: 'a BoxShadow shades the whole foreground rectangle');
        expect(deco.gradient, isNull, reason: 'no scrim over the wallpaper artwork');
      }
    }
  });

  testWidgets('layer order is still background, foreground, clock, foreground copy', (tester) async {
    await pump(tester);
    final images = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .map((i) => i.imageUrl)
        .toList();
    expect(images, [bg, fg, fg]);
    expect(find.byType(ClockRendererWidget), findsOneWidget);
  });
}
