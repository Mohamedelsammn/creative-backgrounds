import 'package:flutter/material.dart';

/// Thin top banner shown when the device is offline. Animates its height so it
/// slides in/out without covering critical UI.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.visible, this.topInset = 0});

  final bool visible;

  /// Status-bar height added on top when visible so text clears the notch.
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: visible ? 28 + topInset : 0,
      width: double.infinity,
      color: const Color(0xFF1E2332),
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(bottom: 6),
      child: visible
          ? const Text(
              'No internet connection',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
