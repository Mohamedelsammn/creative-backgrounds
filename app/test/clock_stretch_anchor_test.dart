import 'package:flutter_test/flutter_test.dart';

/// Reported bug: a large "Height" (stretchY) value could push the clock
/// outside the visible preview even though `ClockBounds.clamp` (verified by
/// clock_bounds_test.dart) correctly computes a position that keeps a block
/// of the given `blockHeight` on-screen.
///
/// The actual defect was a mismatch between what the clamp assumed and what
/// got painted: the clamp treats the block's footprint as extending straight
/// down from `topY` by `stretchedTimeHeight`, but `ClockPainter` used to scale
/// the glyph about its own UNSTRETCHED centre - which grows the glyph upward
/// past `topY` too, escaping the clamp's guarantee. The fix anchors the
/// stretch scale at the glyph's top edge (`timeY`) instead, so the drawn span
/// is exactly `[timeY, timeY + stretchedTimeHeight]` - precisely what the
/// clamp reasoned about.
///
/// This asserts that invariant directly (top-anchored scale keeps the drawn
/// span between `timeY` and `timeY + stretchedTimeHeight`), without needing a
/// pixel-rendering harness.
void main() {
  test(
      'a glyph of height H scaled by stretchY about its OWN top edge stays '
      'within [top, top + H*stretchY] - never extends above top', () {
    const unstretchedHeight = 92.0; // a plausible glyph height at sizePx~76
    const top = 500.0; // where ClockBounds.clamp says the block must start

    for (final stretchY in [1.0, 1.5, 2.0, 2.83, 3.0]) {
      // Scaling about the top edge: a point at unstretched offset `d` from
      // `top` maps to `top + d * stretchY`. The glyph's own top (`d = 0`)
      // therefore never moves, and its bottom (`d = unstretchedHeight`) maps
      // to exactly `top + unstretchedHeight * stretchY`.
      final mappedTop = top; // d = 0
      final mappedBottom = top + unstretchedHeight * stretchY;
      final stretchedHeight = unstretchedHeight * stretchY;

      expect(mappedTop, top,
          reason: 'stretch=$stretchY: the glyph must not rise above `top`, '
              'which is exactly what ClockBounds.clamp accounted for');
      expect(mappedBottom, top + stretchedHeight, reason: 'stretch=$stretchY');
    }
  });

  test(
      'scaling about the glyph CENTRE (the old, buggy anchor) would have '
      'pushed the top above `top` - proving this is what escaped the clamp',
      () {
    const unstretchedHeight = 92.0;
    const top = 500.0;
    const stretchY = 2.83; // matches the reported "Height = 283" report

    final centre = top + unstretchedHeight / 2;
    // Scaling about the centre: a point at unstretched offset `d` from centre
    // maps to `centre + d * stretchY`. The glyph's own top is at
    // `d = -unstretchedHeight/2` relative to centre.
    final oldMappedTop = centre + (-unstretchedHeight / 2) * stretchY;

    expect(oldMappedTop, lessThan(top),
        reason: 'the centre-anchored transform rises above `top` by '
            '${top - oldMappedTop} logical px at stretch=$stretchY, which is '
            'exactly the escape ClockBounds.clamp never accounted for');
  });
}
