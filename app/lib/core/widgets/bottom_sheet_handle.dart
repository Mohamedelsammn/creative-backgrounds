import 'package:flutter/material.dart';

/// Short horizontal drag indicator centered at the top of draggable panels.
class BottomSheetHandle extends StatelessWidget {
  const BottomSheetHandle({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color ?? Colors.white.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
