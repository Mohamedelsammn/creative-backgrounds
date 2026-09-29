import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The splash screen's entrance animation: no static logo image, since the
/// mark this app deserves is what it actually does - a small stack of
/// wallpaper-shaped cards fans out from the centre onto a slowly drifting
/// gradient field of the app's own category accent colors, then settles
/// behind the app name as it reveals. Built entirely from paint/transform
/// primitives already in Flutter, so it costs nothing extra to ship and never
/// depends on an image asset shipping correctly.
class PremiumSplashAnimation extends StatefulWidget {
  const PremiumSplashAnimation({super.key, required this.appName});

  final String appName;

  @override
  State<PremiumSplashAnimation> createState() => _PremiumSplashAnimationState();
}

class _PremiumSplashAnimationState extends State<PremiumSplashAnimation>
    with SingleTickerProviderStateMixin {
  // One-shot entrance: cards fan out, then the name reveals. Never repeats.
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      // Leaves the complete brand lock-up visible briefly before the 3-second
      // minimum splash window ends. The name itself writes for 2.1 seconds.
      duration: const Duration(milliseconds: 2800),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // "Creative Backgrounds" is an English brand name and this whole
    // lock-up is artwork, so it is pinned LTR. Without this, an Arabic app
    // locale flips the letter Row (rendering the name reversed) and mirrors
    // the card fan's horizontal offsets - the brand must look identical in
    // both languages. Scoped to this subtree only: the rest of the app
    // keeps its inherited RTL.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: const RepaintBoundary(
              child: CustomPaint(painter: _AmbientGlowPainter()),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // RepaintBoundary per animated subtree: the fan and the name
              // animate on different schedules, so without these each one's
              // repaint dirties the other's layer every frame.
              RepaintBoundary(
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: _CardFan(progress: _entrance),
                ),
              ),
              const SizedBox(height: 28),
              RepaintBoundary(
                child: _NameReveal(
                  text: widget.appName,
                  entrance: _entrance,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Three to four soft, slowly drifting radial glows in the app's own category
/// accent hues - ties the very first thing a user sees back to the actual
/// content (colorful wallpapers), rather than a generic brand splash.
class _AmbientGlowPainter extends CustomPainter {
  const _AmbientGlowPainter();

  // Mirrors AppColors.categoryAccents['space'/'dark'/'neon'] - the same
  // hues the app's own category cards use, hardcoded here since a const list
  // cannot read from a runtime Map lookup.
  static const _colors = [
    Color(0xFF7B61FF),
    Color(0xFF3A7BD5),
    Color(0xFFF5A623),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const t = math.pi * 0.35;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.55;

    for (var i = 0; i < _colors.length; i++) {
      // Each glow drifts on its own phase-offset orbit, so they never move
      // in lockstep - a single shared phase reads as mechanical, not organic.
      final phase = t + (i * 2 * math.pi / _colors.length);
      final orbit = size.shortestSide * 0.28;
      final glowCenter =
          center +
          Offset(math.cos(phase) * orbit, math.sin(phase * 0.7) * orbit);

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            _colors[i].withValues(alpha: 0.22),
            _colors[i].withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: radius))
        ..blendMode = BlendMode.plus;

      canvas.drawCircle(glowCenter, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientGlowPainter oldDelegate) => false;
}

/// A small stack of rounded, wallpaper-card-shaped rectangles that fan out
/// from stacked-flat to their final splayed arrangement - a miniature,
/// abstracted echo of the app's own card grid, rather than an unrelated
/// generic mark.
/// A small stack of rounded, wallpaper-card-shaped rectangles that fan out
/// from stacked-flat to their final splayed arrangement.
///
/// Each card's decorated [Container] (with its blurred [BoxShadow]) is built
/// exactly ONCE and passed to [AnimatedBuilder] as a `child`; only the two
/// cheap transforms around it are rebuilt per frame. Previously the whole
/// subtree - three shadowed containers - was reconstructed on every tick,
/// which re-resolved and re-rasterized three 20px blur shadows 60 times a
/// second and was a primary source of the splash's dropped frames.
class _CardFan extends StatelessWidget {
  const _CardFan({required this.progress});

  final Animation<double> progress;

  // Each card's final rotation/offset once fully settled, and its accent
  // color - three cards, fanned like a hand of cards.
  static const _cards = [
    (angle: -0.22, dx: -30.0, dy: 6.0, color: Color(0xFF7B61FF)),
    (angle: 0.0, dx: 0.0, dy: -8.0, color: Color(0xFF0D0D0D)),
    (angle: 0.22, dx: 30.0, dy: 6.0, color: Color(0xFFF5A623)),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        for (final card in _cards)
          AnimatedBuilder(
            animation: progress,
            // Built once, reused every frame - never rebuilt by the ticker.
            child: _Card(color: card.color),
            builder: (context, child) {
              // Cards fan out over the animation's first ~70%, with a slight
              // overshoot-and-settle curve so the motion reads as physical,
              // not linear. Unchanged from the original timing/curve.
              final fanT = Curves.easeOutBack.transform(
                (progress.value / 0.7).clamp(0.0, 1.0),
              );
              return Transform.translate(
                offset: Offset(card.dx * fanT, card.dy * fanT),
                child: Transform.rotate(
                  angle: card.angle * fanT,
                  child: child,
                ),
              );
            },
          ),
      ],
    );
  }
}

/// One fanned card. Deliberately const-constructible and shadow-bearing so
/// [_CardFan] can hoist it out of the per-frame rebuild path.
class _Card extends StatelessWidget {
  const _Card({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 88,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
    );
  }
}

/// Reveals [text] letter-by-letter with a short stagger - reads as more
/// deliberate/premium than the whole string fading in at once.
///
/// ## Why this is a painter and not a Row of widgets
///
/// The original built one `Opacity` + `Transform.translate` + `Text` per
/// letter inside a `Row`, and rebuilt that entire subtree on every ticker
/// frame. For "Creative Backgrounds" that is ~20 letters x 3 widgets
/// reconstructed 60 times a second, and critically **each `Opacity` with a
/// fractional value triggers its own `saveLayer`** - about twenty offscreen
/// compositing buffers per frame, which is what made the name reveal drop
/// frames on a mid-range device.
///
/// Here each glyph is laid out ONCE into a [TextPainter] (in [_Glyphs], held
/// by a `StatefulWidget` so layout survives rebuilds), and the per-frame work
/// is reduced to `canvas.drawParagraph` calls with a plain alpha on the text
/// colour - no `saveLayer`, no widget churn, identical visual result.
///
/// The `Row` also carried an RTL bug: under an Arabic `Directionality` it
/// laid the letters out right-to-left, reversing the brand name. A painter
/// advances by its own measured widths, so direction is fixed by
/// construction.
class _NameReveal extends StatefulWidget {
  const _NameReveal({required this.text, required this.entrance});

  final String text;
  final Animation<double> entrance;

  @override
  State<_NameReveal> createState() => _NameRevealState();
}

class _NameRevealState extends State<_NameReveal> {
  static const _style = TextStyle(
    fontFamily: 'Inter',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  late List<_Glyph> _glyphs;
  late Size _size;

  @override
  void initState() {
    super.initState();
    _layout();
  }

  @override
  void didUpdateWidget(_NameReveal old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _layout();
  }

  /// Lays out every glyph once. Re-run only when the text itself changes.
  void _layout() {
    final letters = widget.text.characters.toList();
    var dx = 0.0;
    var height = 0.0;
    _glyphs = [
      for (var i = 0; i < letters.length; i++)
        () {
          final painter = TextPainter(
            text: TextSpan(text: letters[i], style: _style),
            textDirection: TextDirection.ltr,
          )..layout();
          final glyph = _Glyph(
            painter: painter,
            dx: dx,
            // Same staggered window the widget version used: each letter's
            // reveal is a narrow slice of overall progress, left to right.
            start: i / letters.length,
            span: 1.5 / letters.length,
          );
          dx += painter.width;
          height = math.max(height, painter.height);
          return glyph;
        }(),
    ];
    _size = Size(dx, height + 6);
  }

  @override
  void dispose() {
    for (final glyph in _glyphs) {
      glyph.painter.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: _size,
      painter: _NamePainter(glyphs: _glyphs, entrance: widget.entrance),
    );
  }
}

class _Glyph {
  _Glyph({
    required this.painter,
    required this.dx,
    required this.start,
    required this.span,
  });

  final TextPainter painter;
  final double dx;
  final double start;
  final double span;
}

/// Repaints (never rebuilds) the name each frame, driven directly by the
/// entrance animation it listens to via `repaint:`.
class _NamePainter extends CustomPainter {
  _NamePainter({required this.glyphs, required this.entrance})
      : super(repaint: entrance);

  final List<_Glyph> glyphs;
  final Animation<double> entrance;

  @override
  void paint(Canvas canvas, Size size) {
    // Start after the cards establish the mark, then give the writing effect
    // a readable 2.1 seconds (75% of 2.8s) - unchanged timing.
    final nameT = ((entrance.value - 0.25) / 0.75).clamp(0.0, 1.0);
    if (nameT <= 0) return;

    // The whole-block rise the outer Transform used to apply.
    final blockDy = 12 * (1 - nameT);

    for (final glyph in glyphs) {
      final t = ((nameT - glyph.start) / glyph.span).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final offset = Offset(glyph.dx, blockDy + 6 * (1 - t));

      if (t >= 1) {
        // Settled: draw the pre-laid-out glyph directly. No layout, no
        // layer, no allocation - which is the steady state for most glyphs
        // through most of the reveal.
        glyph.painter.paint(canvas, offset);
        continue;
      }

      // Mid-fade: one small saveLayer bounded to this glyph only, instead of
      // the widget tree's full-width Opacity per letter. At most a couple of
      // glyphs are mid-fade in any given frame, since the stagger window is
      // 1.5 letters wide.
      canvas.saveLayer(
        Rect.fromLTWH(
          offset.dx,
          offset.dy,
          glyph.painter.width,
          glyph.painter.height,
        ),
        Paint()..color = const Color(0xFF000000).withValues(alpha: t),
      );
      glyph.painter.paint(canvas, offset);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _NamePainter old) =>
      old.glyphs != glyphs || old.entrance != entrance;
}
