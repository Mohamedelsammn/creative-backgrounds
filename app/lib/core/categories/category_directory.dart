import '../../features/explore/data/models/category_model.dart';

/// In-memory slug -> category lookup.
///
/// Feed, search and related rows identify their category by `categorySlug`
/// alone, but every wallpaper card shows a category *name* (and, where the
/// backend supplies one, an accent color). This directory is populated
/// whenever the category list is fetched or read from cache, and consulted
/// while mapping wallpaper rows.
///
/// A miss is not an error: [lookup] returns null and the mapper synthesizes a
/// readable placeholder from the slug, so a category published after the
/// cached list was fetched still renders sensibly.
class CategoryDirectory {
  final Map<String, CategoryModel> _bySlug = {};

  /// Replaces the directory contents. Called after every successful category
  /// fetch (and after a cache read), so the newest names win.
  void replaceAll(Iterable<CategoryModel> categories) {
    _bySlug
      ..clear()
      ..addEntries(
        categories
            .where((c) => c.slug.isNotEmpty)
            .map((c) => MapEntry(c.slug, c)),
      );
  }

  CategoryModel? lookup(String slug) =>
      slug.isEmpty ? null : _bySlug[slug];

  bool get isEmpty => _bySlug.isEmpty;
}
