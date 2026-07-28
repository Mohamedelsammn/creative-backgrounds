import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/bottom_sheet_handle.dart';
import '../../domain/entities/view_all_options.dart';

/// Radio list of sort options. Returns the chosen [SortOption] via pop.
class SortBottomSheet extends StatelessWidget {
  const SortBottomSheet({super.key, this.current});

  final SortOption? current;

  static Future<SortOption?> show(BuildContext context, SortOption? current) {
    return showModalBottomSheet<SortOption>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SortBottomSheet(current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BottomSheetHandle(color: Color(0xFFDDDDDD)),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Sort by', style: AppTextStyles.sectionTitle),
            ),
          ),
          RadioGroup<SortOption>(
            groupValue: current,
            onChanged: (value) => Navigator.of(context).pop(value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in SortOption.values)
                  RadioListTile<SortOption>(
                    value: option,
                    title: Text(option.label, style: AppTextStyles.bodyLarge),
                    activeColor: Colors.black,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
