import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_search_bar.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/wallpaper_grid.dart';
import '../../../../injection.dart';
import '../bloc/search_bloc.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SearchBloc>(),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) =>
      context.read<SearchBloc>().add(SearchQueryChanged(value));

  void _useHistory(String query) {
    _controller.text = query;
    _controller.selection =
        TextSelection.collapsed(offset: query.length);
    _onChanged(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
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
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onChanged,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<SearchBloc, SearchState>(
                builder: (context, state) => _buildBody(context, state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SearchState state) {
    switch (state) {
      case SearchInitial(:final history):
        return _HistoryView(
          history: history,
          onUse: _useHistory,
          onClear: () =>
              context.read<SearchBloc>().add(const SearchHistoryCleared()),
        );
      case SearchLoading():
        return const Center(child: CircularProgressIndicator());
      case SearchEmpty(:final query):
        return EmptyStateView(
          icon: Icons.search_off_rounded,
          headline: 'No results for "$query"',
          subtext: 'Try a different keyword or category.',
        );
      case SearchError(:final message):
        return ErrorView(
          message: message,
          onRetry: () => _onChanged(_controller.text),
        );
      case SearchLoaded(:final results, :final hasMore):
        return WallpaperGrid(
          wallpapers: results,
          hasMore: hasMore,
          heroPrefix: 'search_hero',
          onLoadMore: () =>
              context.read<SearchBloc>().add(const SearchLoadMoreRequested()),
          onTap: (wallpaper, _) => context.push(
            RouteNames.wallpaperDetailsPath(wallpaper.id),
            extra: wallpaper,
          ),
        );
    }
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({
    required this.history,
    required this.onUse,
    required this.onClear,
  });

  final List<String> history;
  final void Function(String) onUse;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_rounded,
        headline: 'Search wallpapers',
        subtext: 'Find wallpapers by name, category, or tag.',
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.recentSearches, style: AppTextStyles.sectionTitle),
              TextButton(onPressed: onClear, child: Text(context.l10n.clear)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final query in history)
                ActionChip(
                  label: Text(query),
                  backgroundColor: AppColors.surfaceVariant,
                  side: BorderSide.none,
                  onPressed: () => onUse(query),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
