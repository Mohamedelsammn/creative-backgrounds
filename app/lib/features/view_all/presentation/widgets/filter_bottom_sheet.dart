import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/bottom_sheet_handle.dart';
import '../../../explore/domain/entities/category_entity.dart';
import '../../domain/entities/view_all_options.dart';

/// Category checkboxes + orientation selector. Returns [FilterOptions] on Apply.
class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({
    super.key,
    required this.categories,
    required this.current,
  });

  final List<CategoryEntity> categories;
  final FilterOptions current;

  static Future<FilterOptions?> show(
    BuildContext context, {
    required List<CategoryEntity> categories,
    required FilterOptions current,
  }) {
    return showModalBottomSheet<FilterOptions>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          FilterBottomSheet(categories: categories, current: current),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late Set<String> _categoryIds;
  late WallpaperOrientation _orientation;

  @override
  void initState() {
    super.initState();
    _categoryIds = widget.current.categoryIds.toSet();
    _orientation = widget.current.orientation;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BottomSheetHandle(color: Color(0xFFDDDDDD)),
              const SizedBox(height: 8),
              Text('Filters', style: AppTextStyles.sectionTitle),
              if (widget.categories.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('CATEGORIES',
                    style: AppTextStyles.overline
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in widget.categories)
                      FilterChip(
                        label: Text(category.name),
                        selected: _categoryIds.contains(category.id),
                        showCheckmark: false,
                        backgroundColor: AppColors.surfaceVariant,
                        selectedColor: AppColors.primary,
                        labelStyle: AppTextStyles.bodySmall.copyWith(
                          color: _categoryIds.contains(category.id)
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide.none,
                        onSelected: (selected) => setState(() {
                          selected
                              ? _categoryIds.add(category.id)
                              : _categoryIds.remove(category.id);
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Text('ORIENTATION',
                  style: AppTextStyles.overline
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              RadioGroup<WallpaperOrientation>(
                groupValue: _orientation,
                onChanged: (value) => setState(
                    () => _orientation = value ?? WallpaperOrientation.all),
                child: Column(
                  children: [
                    for (final orientation in WallpaperOrientation.values)
                      RadioListTile<WallpaperOrientation>(
                        value: orientation,
                        contentPadding: EdgeInsets.zero,
                        title: Text(orientation.label,
                            style: AppTextStyles.bodyMedium),
                        activeColor: Colors.black,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _categoryIds.clear();
                        _orientation = WallpaperOrientation.all;
                      }),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(
                        FilterOptions(
                          categoryIds: _categoryIds.toList(),
                          orientation: _orientation,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: AppShapes.pillBorder,
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
