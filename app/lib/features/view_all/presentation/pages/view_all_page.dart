import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/filter_chip.dart';
import '../../../../core/widgets/sort_chip.dart';
import '../../../../core/widgets/wallpaper_grid.dart';
import '../../../../injection.dart';
import '../../../explore/domain/entities/category_entity.dart';
import '../../../explore/domain/usecases/get_categories_usecase.dart';
import '../../domain/entities/view_all_options.dart';
import '../bloc/view_all_bloc.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/sort_bottom_sheet.dart';

class ViewAllPage extends StatelessWidget {
  const ViewAllPage({super.key, required this.section});

  final String section;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<ViewAllBloc>()..add(ViewAllFetchRequested(section)),
      child: _ViewAllView(section: section),
    );
  }
}

class _ViewAllView extends StatefulWidget {
  const _ViewAllView({required this.section});

  final String section;

  @override
  State<_ViewAllView> createState() => _ViewAllViewState();
}

class _ViewAllViewState extends State<_ViewAllView> {
  List<CategoryEntity> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final result = await sl<GetCategoriesUseCase>()(const NoParams());
    result.fold((_) {}, (categories) {
      if (mounted) setState(() => _categories = categories);
    });
  }

  String get _title {
    switch (widget.section) {
      case 'trending':
        return 'Trending';
      case 'latest':
        return 'Latest';
      case 'all':
        return 'All';
      default:
        return _categories
            .where((c) => c.id == widget.section)
            .map((c) => c.name)
            .firstOrNull ??
            'Wallpapers';
    }
  }

  Future<void> _openFilter(BuildContext context, FilterOptions current) async {
    final result = await FilterBottomSheet.show(
      context,
      categories: _categories,
      current: current,
    );
    if (result != null && context.mounted) {
      context.read<ViewAllBloc>().add(ViewAllFilterApplied(result));
    }
  }

  Future<void> _openSort(BuildContext context, SortOption? current) async {
    final result = await SortBottomSheet.show(context, current);
    if (result != null && context.mounted) {
      context.read<ViewAllBloc>().add(ViewAllSortApplied(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, 8, AppSpacing.screenH, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: AppSearchBar(
                        onTap: () => context.push(RouteNames.search)),
                  ),
                ],
              ),
            ),
            BlocBuilder<ViewAllBloc, ViewAllState>(
              builder: (context, state) {
                final filter = state is ViewAllLoaded
                    ? state.activeFilter
                    : const FilterOptions();
                final sort =
                    state is ViewAllLoaded ? state.activeSort : null;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, 8, AppSpacing.screenH, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _title,
                          style: AppTextStyles.displayLarge.copyWith(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                      FilterPill(
                        active: filter.isActive,
                        onTap: () => _openFilter(context, filter),
                      ),
                      const SizedBox(width: 8),
                      SortPill(
                        active: sort != null,
                        onTap: () => _openSort(context, sort),
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: BlocBuilder<ViewAllBloc, ViewAllState>(
                builder: (context, state) => _buildBody(context, state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ViewAllState state) {
    switch (state) {
      case ViewAllInitial():
      case ViewAllLoading():
        return const Center(child: CircularProgressIndicator());
      case ViewAllError(:final message):
        return ErrorView(
          message: message,
          onRetry: () => context
              .read<ViewAllBloc>()
              .add(ViewAllFetchRequested(widget.section)),
        );
      case ViewAllLoaded(:final items, :final hasMore):
        return WallpaperGrid(
          wallpapers: items,
          hasMore: hasMore,
          heroPrefix: 'viewall_${widget.section}_hero',
          onLoadMore: () =>
              context.read<ViewAllBloc>().add(const ViewAllLoadMoreRequested()),
          onTap: (wallpaper, heroTag) => context.push(
            RouteNames.wallpaperDetailsPath(wallpaper.id),
            extra: heroTag,
          ),
        );
    }
  }
}
