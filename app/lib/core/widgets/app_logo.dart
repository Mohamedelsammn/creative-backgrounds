import 'package:flutter/material.dart';

/// Shared brand mark for the app.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 96,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Creative Backgrounds logo',
      image: true,
      child: Image.asset(
        'assets/images/app_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
