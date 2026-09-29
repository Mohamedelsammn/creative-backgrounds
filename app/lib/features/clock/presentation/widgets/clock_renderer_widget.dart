import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/entities/clock_config_entity.dart';
import 'clock_painter.dart';

/// Live clock preview. Ticks once per second and repaints via [ClockPainter].
class ClockRendererWidget extends StatefulWidget {
  const ClockRendererWidget({
    super.key,
    required this.config,
    this.locale,
    this.displayScale = 1.0,
    this.fixedTime,
  });

  final ClockConfigEntity config;
  final String? locale;

  /// Forwarded to [ClockPainter.displayScale] - identity for a full-size
  /// render, less than 1.0 for a smaller preview box. See that field's doc
  /// for why a shrunk preview needs it.
  final double displayScale;

  /// Freezes the clock at this time (tests / goldens). Null ticks live.
  final DateTime? fixedTime;

  @override
  State<ClockRendererWidget> createState() => _ClockRendererWidgetState();
}

class _ClockRendererWidgetState extends State<ClockRendererWidget> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = widget.fixedTime ?? DateTime.now();
    if (widget.fixedTime != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: ClockPainter(
          config: widget.config,
          now: _now,
          locale: widget.locale,
          deviceIs24Hour: MediaQuery.maybeAlwaysUse24HourFormatOf(context) ?? false,
          displayScale: widget.displayScale,
        ),
      ),
    );
  }
}
