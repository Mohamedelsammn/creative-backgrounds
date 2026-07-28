import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_colors.dart';

/// A single destination in the floating bottom nav.
class BottomNavDestination {
  const BottomNavDestination({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Pill-shaped floating bottom navigation with three destinations.
///
/// The active black indicator slides between tabs with a spring simulation and
/// can be dragged directly with a finger (it follows in real time, then snaps
/// to the nearest tab on release). Navigation is committed only *after* the
/// indicator settles — never instantly. The glass bar, blur, dimensions and
/// spacing are unchanged; only the selection behaviour is animated, and only
/// the indicator/icons subtree rebuilds (never the Scaffold).
class FloatingBottomNav extends StatefulWidget {
  const FloatingBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.visible = true,
    this.destinations = defaultDestinations,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool visible;
  final List<BottomNavDestination> destinations;

  static const List<BottomNavDestination> defaultDestinations = [
    BottomNavDestination(icon: Icons.explore_outlined, label: 'Explore'),
    BottomNavDestination(icon: Icons.favorite_border, label: 'Favorites'),
    BottomNavDestination(icon: Icons.wb_sunny_outlined, label: 'Settings'),
  ];

  @override
  State<FloatingBottomNav> createState() => _FloatingBottomNavState();
}

class _FloatingBottomNavState extends State<FloatingBottomNav>
    with SingleTickerProviderStateMixin {
  // Base (unscaled) geometry — identical to the previous design.
  static const double _itemWidth = 62;
  static const double _itemHeight = 53;
  static const double _itemMargin = 4; // per side
  static const double _iconSize = 26;
  static const double _outerPad = 10;

  // Premium, slightly heavy spring with a very subtle overshoot (damping ratio
  // ~0.85). Settles in ~320–380ms.
  static const SpringDescription _spring =
      SpringDescription(mass: 1, stiffness: 200, damping: 24);

  late final AnimationController _controller;

  /// The tab the current spring is settling to (used to snap-stop the spring's
  /// imperceptible tail so it doesn't tick needlessly).
  double? _animTarget;

  /// The tab whose navigation is still pending commit. Committed as soon as the
  /// indicator is *visually* at the target — never waiting for the spring's
  /// mathematical settle (which can take seconds).
  int? _pendingNavIndex;
  bool _dragging = false;
  double _scale = 1;

  /// A fraction of a slot: once the indicator is this close to the target we
  /// consider it "arrived" for navigation-commit purposes.
  static const double _arriveThreshold = 0.06;

  double get _itemExtent => (_itemWidth + _itemMargin * 2) * _scale;

  int get _count => widget.destinations.length;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: widget.currentIndex.toDouble(),
    );
    _controller.addListener(_onTick);
  }

  /// Runs every animation frame. Commits the pending navigation the instant the
  /// indicator is visually at the target, and stops the spring's imperceptible
  /// settle tail so it never ticks (or blocks navigation) for seconds.
  void _onTick() {
    if (_dragging) return;
    final pending = _pendingNavIndex;
    if (pending != null &&
        (_controller.value - pending).abs() <= _arriveThreshold) {
      _pendingNavIndex = null;
      if (mounted && pending != widget.currentIndex) widget.onTap(pending);
    }
    final t = _animTarget;
    if (t != null &&
        _controller.isAnimating &&
        (_controller.value - t).abs() < 0.004) {
      _controller.stop();
      _controller.value = t;
    }
  }

  @override
  void didUpdateWidget(covariant FloatingBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    // React to an external index change (e.g. deep link) — but not to our own
    // navigation, where the indicator has already settled on the new index.
    if (oldWidget.currentIndex != widget.currentIndex &&
        !_dragging &&
        _controller.value.round() != widget.currentIndex) {
      _animateAndNavigate(widget.currentIndex, commit: false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Springs the indicator to [index]. Navigation is committed by [_onTick] the
  /// moment the indicator is visually at the target — not when the spring's
  /// mathematical tail finally settles (which can take seconds).
  void _animateAndNavigate(int index, {double velocity = 0, bool commit = true}) {
    final target = index.toDouble();
    _animTarget = target;
    _pendingNavIndex = commit ? index : null;
    final sim = SpringSimulation(_spring, _controller.value, target, velocity);
    _controller.animateWith(sim);
  }

  /// Resolves which tab a tap landed on from its x-offset within the bar. A
  /// single gesture detector owns both taps and drags, so there is no nested
  /// tap/drag arena conflict.
  void _onTapAt(double dx) {
    final index = (dx / _itemExtent).floor().clamp(0, _count - 1);
    if (index == _controller.value.round() && index == widget.currentIndex) {
      return; // already here
    }
    _animateAndNavigate(index);
  }

  void _onDragStart(DragStartDetails _) {
    _dragging = true;
    _controller.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final next = _controller.value + details.primaryDelta! / _itemExtent;
    _controller.value = next.clamp(0.0, (_count - 1).toDouble());
  }

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;
    final nearest = _controller.value.round().clamp(0, _count - 1);
    final velocity = details.primaryVelocity != null
        ? details.primaryVelocity! / _itemExtent
        : 0.0;
    _animateAndNavigate(nearest, velocity: velocity);
  }

  @override
  Widget build(BuildContext context) {
    // Scale the whole pill proportionally to screen width so it never looks
    // oversized on small phones nor cramped on large ones (~320–800dp).
    final width = MediaQuery.sizeOf(context).width;
    _scale = (width / 400).clamp(0.82, 1.0);
    final outerPad = _outerPad * _scale;
    final ext = _itemExtent;
    final rowWidth = ext * _count;
    final rowHeight = _itemHeight * _scale;

    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        offset: widget.visible ? Offset.zero : const Offset(0, 1.5),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: widget.visible ? 1 : 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    // Frosted glass: translucent white over a heavy blur.
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 0.5,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                      horizontal: outerPad, vertical: outerPad),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _onTapAt(d.localPosition.dx),
                    onHorizontalDragStart: _onDragStart,
                    onHorizontalDragUpdate: _onDragUpdate,
                    onHorizontalDragEnd: _onDragEnd,
                    child: SizedBox(
                      width: rowWidth,
                      height: rowHeight,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          final pos = _controller.value;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Sliding black indicator pill.
                              Positioned(
                                left: pos * ext + _itemMargin * _scale,
                                top: 0,
                                child: Container(
                                  width: _itemWidth * _scale,
                                  height: rowHeight,
                                  decoration: BoxDecoration(
                                    color: AppColors.activeNav,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                              // Icons — colour/scale interpolate with distance
                              // from the indicator.
                              Row(
                                children: [
                                  for (var i = 0; i < _count; i++)
                                    _NavIcon(
                                      destination: widget.destinations[i],
                                      extent: ext,
                                      scale: _scale,
                                      iconSize: _iconSize * _scale,
                                      selectedness:
                                          (1 - (pos - i).abs()).clamp(0.0, 1.0),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.destination,
    required this.extent,
    required this.scale,
    required this.iconSize,
    required this.selectedness,
  });

  final BottomNavDestination destination;
  final double extent;
  final double scale;
  final double iconSize;

  /// 1.0 when the indicator is exactly over this icon, 0.0 one slot away.
  final double selectedness;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(
      AppColors.textSecondary,
      Colors.white,
      selectedness,
    )!;
    final iconScale = 1.0 + 0.1 * selectedness; // 1.0 → 1.1
    return Semantics(
      label: destination.label,
      selected: selectedness > 0.5,
      button: true,
      child: SizedBox(
        width: extent,
        height: 53 * scale,
        child: Center(
          child: Transform.scale(
            scale: iconScale,
            child: Icon(destination.icon, size: iconSize, color: color),
          ),
        ),
      ),
    );
  }
}
