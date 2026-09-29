import 'package:creativebackground/core/l10n/generated/app_localizations.dart';
import 'package:creativebackground/features/explore/domain/entities/category_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_entity.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:creativebackground/features/wallpaper_details/presentation/widgets/wallpaper_info_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Details screen's Apply button must be WHITE with BLACK text - an
/// earlier pass on this panel made it black/white, which the redesign spec
/// explicitly calls out as wrong.
void main() {
  const category = CategoryEntity(id: 'cat-1', name: 'Nature');

  WallpaperEntity wallpaper(WallpaperType type) => WallpaperEntity(
        id: 'w1',
        title: 'Wallpaper',
        category: category,
        type: type,
        thumbnailUrl: 'https://cdn.test/w1.webp',
        fullUrl: 'https://cdn.test/w1.webp',
        resolution: '1080x1920',
      );

  Future<void> pump(WidgetTester tester, WallpaperInfoPanel panel) {
    return tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: panel)),
    ));
  }

  testWidgets('Normal wallpaper: Apply button is a white Material with '
      'black text', (tester) async {
    await pump(
      tester,
      WallpaperInfoPanel(wallpaper: wallpaper(WallpaperType.normal), onApply: () {}),
    );

    final applyText = tester.widget<Text>(find.text('Apply'));
    expect(applyText.style?.color, Colors.black);

    final material = tester.widget<Material>(
      find.ancestor(of: find.text('Apply'), matching: find.byType(Material)).first,
    );
    expect(material.color, Colors.white);
  });

  testWidgets('Live wallpaper: Apply button is still white/black, with a '
      'separate Play/Pause control beside it (not overlaid on the video)',
      (tester) async {
    await pump(
      tester,
      WallpaperInfoPanel(
        wallpaper: wallpaper(WallpaperType.live),
        onApply: () {},
        isPlaying: true,
        onPlayPauseToggle: () {},
      ),
    );

    final applyText = tester.widget<Text>(find.text('Apply'));
    expect(applyText.style?.color, Colors.black);
    final material = tester.widget<Material>(
      find.ancestor(of: find.text('Apply'), matching: find.byType(Material)).first,
    );
    expect(material.color, Colors.white);

    expect(find.byIcon(Icons.pause), findsOneWidget);
  });
}
