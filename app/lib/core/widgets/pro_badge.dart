import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

/// Small white "PRO" pill shown on premium wallpaper cards.
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        'PRO',
        style: AppTextStyles.caption.copyWith(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          fontSize: 10,
        ),
      ),
    );
  }
}
