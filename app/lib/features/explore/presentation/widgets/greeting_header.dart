import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Time-aware greeting eyebrow + "Discover Wallpapers" title.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key, this.now});

  /// Injectable for testing; defaults to `DateTime.now()`.
  final DateTime? now;

  String _greeting(BuildContext context, int hour) {
    final l10n = context.l10n;
    if (hour >= 5 && hour <= 11) return l10n.goodMorning;
    if (hour >= 12 && hour <= 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  @override
  Widget build(BuildContext context) {
    final hour = (now ?? DateTime.now()).hour;
    // Scale the title with screen width so it never crowds the header on small
    // phones (~320dp) while keeping the same size on normal/large phones.
    final titleSize = (MediaQuery.sizeOf(context).width * 0.088).clamp(27.0, 34.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_greeting(context, hour), style: AppTextStyles.overline),
        const SizedBox(height: 6),
        Text(
          context.l10n.discoverWallpapers,
          style: AppTextStyles.displayLarge.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: titleSize,
            height: 1.04,
            letterSpacing: -1.0,
          ),
        ),
      ],
    );
  }
}
