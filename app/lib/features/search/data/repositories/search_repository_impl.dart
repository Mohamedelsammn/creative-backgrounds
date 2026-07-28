import 'dart:convert';

import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/pagination/paginated.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../../explore/domain/entities/wallpaper_entity.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/search_remote_datasource.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._remote, this._storage);

  final SearchRemoteDatasource _remote;
  final HiveStorage _storage;

  static const _maxHistory = 10;

  @override
  Future<Either<Failure, Paginated<WallpaperEntity>>> search(
    String query, {
    int page = 1,
  }) async {
    try {
      final result = await _remote.search(query, page: page);
      return Right(Paginated<WallpaperEntity>(
        items: result.items.map((m) => m.toEntity()).toList(),
        page: result.page,
        hasMore: result.hasMore,
        total: result.total,
      ));
    } catch (e) {
      return Left(ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  List<String> getHistory() {
    final raw = _storage.read<String>(
        HiveBoxes.searchHistory, StorageKeys.searchHistory);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> addToHistory(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return Future.value();
    final history = getHistory()
      ..removeWhere((q) => q.toLowerCase() == trimmed.toLowerCase());
    history.insert(0, trimmed);
    final capped = history.take(_maxHistory).toList();
    return _storage.write(
      HiveBoxes.searchHistory,
      StorageKeys.searchHistory,
      jsonEncode(capped),
    );
  }

  @override
  Future<void> clearHistory() {
    return _storage.delete(HiveBoxes.searchHistory, StorageKeys.searchHistory);
  }
}
