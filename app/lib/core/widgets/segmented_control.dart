import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

/// Dark frosted 3-segment control (Clock · Styles · Depth) used in Customize.
/// The selected segment slides under a white pill.
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSegmentChanged,
  });

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onSegmentChanged;

  @override
  Widget build(BuildContext context) {
    final count = segments.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 4.0;
        final segmentWidth = (constraints.maxWidth - padding * 2) / count;
        return Container(
          height: 44,
          padding: const EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                left: segmentWidth * selectedIndex,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSegmentChanged(i),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: i == selectedIndex
                                  ? Colors.black
                                  : Colors.white70,
                            ),
                            child: Text(segments[i]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
