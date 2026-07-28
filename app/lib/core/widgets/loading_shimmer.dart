import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_shapes.dart';

/// Rounded shimmer placeholder used while cards/images load.
class LoadingShimmer extends StatelessWidget {
  const LoadingShimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEDEDED),
      highlightColor: const Color(0xFFF7F7F7),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? AppShapes.card,
        ),
      ),
    );
  }
}
