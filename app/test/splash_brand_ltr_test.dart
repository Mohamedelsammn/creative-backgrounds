import 'package:creativebackground/features/splash/presentation/widgets/premium_splash_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Creative Backgrounds" is an English brand name and the whole splash
/// lock-up is artwork, so it must look IDENTICAL in both app languages.
///
/// The name reveal used to be a `Row` of per-letter widgets. Under an Arabic
/// `Directionality` a `Row` lays its children right-to-left, so the brand
/// rendered reversed, and the card fan's horizontal offsets were mirrored
/// too. `PremiumSplashAnimation` now pins its own subtree to
/// `TextDirection.ltr`.
void main() {
  Widget host(TextDirection direction) => MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: const Scaffold(
            body: Center(
              child: PremiumSplashAnimation(appName: 'Creative Backgrounds'),
            ),
          ),
        ),
      );

  /// The direction actually in force inside the animation's own subtree,
  /// read from the deepest element the animation builds.
  TextDirection effectiveDirection(WidgetTester tester) {
    final inner = find
        .descendant(
          of: find.byType(PremiumSplashAnimation),
          matching: find.byType(CustomPaint),
        )
        .evaluate();
    expect(inner, isNotEmpty, reason: 'expected the animation to paint');
    return Directionality.of(inner.last);
  }

  testWidgets('under an LTR (English) app locale the brand subtree is LTR',
      (tester) async {
    await tester.pumpWidget(host(TextDirection.ltr));
    await tester.pump(const Duration(milliseconds: 100));
    expect(effectiveDirection(tester), TextDirection.ltr);
  });

  testWidgets(
    'under an RTL (Arabic) app locale the brand subtree is STILL LTR - the '
    'brand must never mirror',
    (tester) async {
      await tester.pumpWidget(host(TextDirection.rtl));
      await tester.pump(const Duration(milliseconds: 100));
      expect(effectiveDirection(tester), TextDirection.ltr);
    },
  );

  testWidgets(
    'the surrounding app keeps its RTL - only the brand subtree is pinned',
    (tester) async {
      await tester.pumpWidget(host(TextDirection.rtl));
      await tester.pump(const Duration(milliseconds: 100));
      // The Scaffold above the animation still sees RTL, proving the
      // override is scoped and does not force the whole app to LTR.
      final outer = tester.element(find.byType(Scaffold));
      expect(Directionality.of(outer), TextDirection.rtl);
    },
  );

  testWidgets(
    'the brand renders at the same position in Arabic as in English',
    (tester) async {
      await tester.pumpWidget(host(TextDirection.ltr));
      await tester.pump(const Duration(milliseconds: 1500));
      final ltrRect = tester.getRect(find.byType(PremiumSplashAnimation));

      await tester.pumpWidget(host(TextDirection.rtl));
      await tester.pump(const Duration(milliseconds: 1500));
      final rtlRect = tester.getRect(find.byType(PremiumSplashAnimation));

      expect(rtlRect, ltrRect,
          reason: 'the lock-up must occupy the same box in both locales');
    },
  );

  testWidgets('the brand text is never translated', (tester) async {
    await tester.pumpWidget(host(TextDirection.rtl));
    await tester.pump(const Duration(milliseconds: 1500));
    final widget = tester.widget<PremiumSplashAnimation>(
      find.byType(PremiumSplashAnimation),
    );
    expect(widget.appName, 'Creative Backgrounds');
  });

  testWidgets('the animation completes without throwing in either direction',
      (tester) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(host(direction));
      // Past the full 2.8s entrance.
      await tester.pump(const Duration(milliseconds: 3000));
      expect(tester.takeException(), isNull);
    }
  });
}
