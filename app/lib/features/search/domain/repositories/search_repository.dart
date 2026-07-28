import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/pagination/paginated.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';

abstract class SearchRepository {
  Future<Either<Failure, Paginated<WallpaperEntity>>> search(
    String query, {
    int page = 1,
  });

  /// Last-10 recent queries (most recent first), stored locally in Hive.
  List<String> getHistory();
  Future<void> addToHistory(String query);
  Future<void> clearHistory();
}
