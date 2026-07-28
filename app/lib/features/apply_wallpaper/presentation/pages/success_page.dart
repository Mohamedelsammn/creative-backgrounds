import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../core/theme/app_text_styles.dart';

class SuccessPage extends StatefulWidget {
  const SuccessPage({super.key});

  @override
  State<SuccessPage> createState() => _SuccessPageState();
}

class _SuccessPageState extends State<SuccessPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Prevent back navigation (no re-apply); Done resets to Explore.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => CustomPaint(
                      painter: _CheckmarkPainter(_controller.value),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                _fadeUp(
                  interval: const Interval(0.5, 1.0),
                  child: Text(context.l10n.wallpaperApplied,
                      style: AppTextStyles.displayLarge.copyWith(fontSize: 26)),
                ),
                const SizedBox(height: 10),
                _fadeUp(
                  interval: const Interval(0.6, 1.0),
                  child: Text(
                    context.l10n.wallpaperAppliedSubtitle,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
                _fadeUp(
                  interval: const Interval(0.7, 1.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go(RouteNames.explore),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: AppShapes.pillBorder,
                      ),
                      child: Text(context.l10n.done),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fadeUp({required Interval interval, required Widget child}) {
    final anim = CurvedAnimation(parent: _controller, curve: interval);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * 12),
          child: child,
        ),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  _CheckmarkPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    // Circle background.
    final circlePaint = Paint()..color = AppColors.primary;
    final circleProgress = (progress / 0.5).clamp(0.0, 1.0);
    canvas.drawCircle(center, radius * circleProgress, circlePaint);

    if (progress <= 0.45) return;

    // Checkmark path.
    final checkProgress = ((progress - 0.45) / 0.55).clamp(0.0, 1.0);
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.66)
      ..lineTo(size.width * 0.72, size.height * 0.36);

    final metric = path.computeMetrics().first;
    final extracted =
        metric.extractPath(0, metric.length * checkProgress);
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(extracted, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter old) =>
      old.progress != progress;
}
