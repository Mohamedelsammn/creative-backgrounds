import 'package:creativebackground/core/widgets/color_swatch_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The expanded curated color palette (Change 2) must be a genuine superset
/// of the original 4-color default palette, so any wallpaper saved before
/// this palette existed still finds its color highlighted as a preset swatch
/// rather than falling through to "no selection matches".
void main() {
  test('curatedColors contains every defaultColors entry', () {
    for (final color in ColorSwatchRow.defaultColors) {
      expect(
        ColorSwatchRow.curatedColors.any((c) => c.toARGB32() == color.toARGB32()),
        isTrue,
        reason: '$color from the original default palette is missing from '
            'curatedColors - an old saved wallpaper using it would no longer '
            'show a selected preset swatch',
      );
    }
  });

  test('curatedColors is a meaningfully larger, curated palette (30+ colors, '
      'not hundreds of generated ones)', () {
    expect(ColorSwatchRow.curatedColors.length, greaterThanOrEqualTo(30));
    expect(ColorSwatchRow.curatedColors.length, lessThan(100));
  });

  test('curatedColors has no duplicate entries', () {
    final seen = <int>{};
    for (final color in ColorSwatchRow.curatedColors) {
      final argb = color.toARGB32();
      expect(seen.contains(argb), isFalse,
          reason: '$color appears more than once in curatedColors');
      seen.add(argb);
    }
  });

  testWidgets('tapping the first preset swatch calls onSelected with that '
      'color', (tester) async {
    Color? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ColorSwatchRow(
          colors: ColorSwatchRow.curatedColors,
          selectedColor: ColorSwatchRow.curatedColors.first,
          onSelected: (c) => picked = c,
        ),
      ),
    ));

    final gestureDetectors = find.descendant(
      of: find.byType(ColorSwatchRow),
      matching: find.byType(GestureDetector),
    );
    expect(gestureDetectors, findsWidgets);

    await tester.tap(gestureDetectors.first);
    await tester.pump();
    expect(picked, ColorSwatchRow.curatedColors.first);
  });

  testWidgets('the Custom swatch appears only when onCustomTap is provided '
      'and invokes it on tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ColorSwatchRow(
          colors: ColorSwatchRow.curatedColors,
          selectedColor: ColorSwatchRow.curatedColors.first,
          onSelected: (_) {},
          onCustomTap: () => tapped = true,
        ),
      ),
    ));

    final customSwatch = find.bySemanticsLabel('Custom color');
    expect(customSwatch, findsOneWidget);

    // The row is horizontally scrollable and the curated palette is wide
    // enough that the trailing Custom swatch starts off-screen.
    await tester.scrollUntilVisible(
      customSwatch,
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(customSwatch);
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('the Custom swatch is absent when onCustomTap is omitted',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ColorSwatchRow(
          colors: ColorSwatchRow.curatedColors,
          selectedColor: ColorSwatchRow.curatedColors.first,
          onSelected: (_) {},
        ),
      ),
    ));

    expect(find.bySemanticsLabel('Custom color'), findsNothing);
  });
}
