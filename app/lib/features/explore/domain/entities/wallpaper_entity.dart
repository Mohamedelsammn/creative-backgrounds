import 'package:equatable/equatable.dart';

import 'category_entity.dart';

/// Core wallpaper domain model, shared across explore, search, view-all,
/// details and favorites features.
class WallpaperEntity extends Equatable {
  const WallpaperEntity({
    required this.id,
    required this.title,
    required this.category,
    required this.thumbnailUrl,
    required this.fullUrl,
    required this.resolution,
    this.isPremium = false,
    this.hasForegroundMask = false,
    this.foregroundMaskUrl,
    this.downloadCount = 0,
    this.fileSizeBytes,
    this.tags = const [],
    this.createdAt,
  });

  final String id;
  final String title;
  final CategoryEntity category;
  final String thumbnailUrl;
  final String fullUrl;

  /// e.g. "2160x3840".
  final String resolution;

  final bool isPremium;

  /// Whether a foreground-subject mask exists (enables the depth effect).
  final bool hasForegroundMask;
  final String? foregroundMaskUrl;

  final int downloadCount;
  final int? fileSizeBytes;
  final List<String> tags;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [
        id,
        title,
        category,
        thumbnailUrl,
        fullUrl,
        resolution,
        isPremium,
        hasForegroundMask,
        foregroundMaskUrl,
        downloadCount,
        fileSizeBytes,
        tags,
        createdAt,
      ];
}
