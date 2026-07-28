import 'package:flutter/material.dart';

import 'filter_chip.dart';

/// "Sort" pill (reuses [IconPillChip]).
class SortPill extends StatelessWidget {
  const SortPill({super.key, required this.onTap, this.active = false});
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => IconPillChip(
        icon: Icons.swap_vert_rounded,
        label: 'Sort',
        onTap: onTap,
        active: active,
      );
}
