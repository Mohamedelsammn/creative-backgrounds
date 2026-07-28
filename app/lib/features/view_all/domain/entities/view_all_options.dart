import 'package:equatable/equatable.dart';

enum SortOption {
  trending('trending', 'Trending'),
  latest('latest', 'Latest'),
  downloads('downloads', 'Most Downloaded'),
  alphabetical('alphabetical', 'Alphabetical');

  const SortOption(this.value, this.label);
  final String value;
  final String label;
}

/// Named to avoid collision with Flutter's `Orientation` enum.
enum WallpaperOrientation {
  portrait('portrait', 'Portrait'),
  landscape('landscape', 'Landscape'),
  all('all', 'All');

  const WallpaperOrientation(this.value, this.label);
  final String value;
  final String label;
}

class FilterOptions extends Equatable {
  const FilterOptions({
    this.categoryIds = const [],
    this.orientation = WallpaperOrientation.all,
  });

  final List<String> categoryIds;
  final WallpaperOrientation orientation;

  bool get isActive =>
      categoryIds.isNotEmpty || orientation != WallpaperOrientation.all;

  FilterOptions copyWith({
    List<String>? categoryIds,
    WallpaperOrientation? orientation,
  }) {
    return FilterOptions(
      categoryIds: categoryIds ?? this.categoryIds,
      orientation: orientation ?? this.orientation,
    );
  }

  @override
  List<Object?> get props => [categoryIds, orientation];
}
