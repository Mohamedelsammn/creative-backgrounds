import 'package:creativebackground/core/widgets/wallpaper_type_badge.dart';
import 'package:creativebackground/features/explore/domain/entities/wallpaper_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A live wallpaper's card badge shows its actual running time (e.g. "0:10")
/// once known, instead of the generic "LIVE" label. The feed's list rows
/// never carry `video.durationMs` (only the detail response does), so a Home
/// card still falls back to "LIVE" - only Details, once the full wallpaper
/// has loaded, has a duration to show.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: Material(child: child)));

  testWidgets('no durationMs falls back to the generic "LIVE" label',
      (tester) async {
    await pump(tester, const WallpaperTypeBadge(type: WallpaperType.live));

    expect(find.text('LIVE'), findsOneWidget);
  });

  testWidgets('a duration under a minute renders as m:ss, e.g. "0:10"',
      (tester) async {
    await pump(
      tester,
      const WallpaperTypeBadge(type: WallpaperType.live, durationMs: 10000),
    );

    expect(find.text('0:10'), findsOneWidget);
  });

  testWidgets('a duration over a minute renders minutes:seconds, e.g. "1:05"',
      (tester) async {
    await pump(
      tester,
      const WallpaperTypeBadge(type: WallpaperType.live, durationMs: 65000),
    );

    expect(find.text('1:05'), findsOneWidget);
  });

  testWidgets('seconds are zero-padded below 10, e.g. "0:05" not "0:5"',
      (tester) async {
    await pump(
      tester,
      const WallpaperTypeBadge(type: WallpaperType.live, durationMs: 5000),
    );

    expect(find.text('0:05'), findsOneWidget);
  });

  testWidgets(
      'durationMs is ignored for a non-live type - DEPTH never shows a '
      'duration', (tester) async {
    await pump(
      tester,
      const WallpaperTypeBadge(type: WallpaperType.depth, durationMs: 10000),
    );

    expect(find.text('DEPTH'), findsOneWidget);
    expect(find.text('0:10'), findsNothing);
  });
}
