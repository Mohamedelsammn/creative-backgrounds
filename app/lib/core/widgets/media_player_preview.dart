import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Fallback in-app preview for a looping video wallpaper, rendered by a
/// native Android `MediaPlayer` (via [MediaPlayerPreviewView] on the Kotlin
/// side) instead of the `video_player` plugin's ExoPlayer/Media3 pipeline.
///
/// Used only when `video_player` reports an initialization error -
/// [LiveWallpaperPlayer] falls back to this automatically. See
/// `MediaPlayerPreviewView`'s doc comment for why this exists: some MediaTek
/// chipsets fail ExoPlayer's stricter codec-configuration sequence for
/// content that plays back fine through plain `MediaPlayer`, which is what
/// the already-working applied-wallpaper path
/// (`VideoWallpaperService`) has always used.
///
/// ## Why the clip is cached to disk first
///
/// Handing the native view a remote URL directly would make its own
/// `MediaPlayer.prepareAsync()` open the HTTP connection and buffer before
/// the first frame is ready - on top of the `video_player` attempt that
/// already failed to get here. [DefaultCacheManager] downloads the clip once
/// (or returns the file instantly if a prior card, or a prior visit to this
/// same wallpaper, already fetched it) so the native side only ever decodes
/// a local file, matching the already-fast applied-wallpaper path.
class MediaPlayerPreview extends StatefulWidget {
  const MediaPlayerPreview({super.key, required this.videoUrl});

  final String videoUrl;

  @override
  State<MediaPlayerPreview> createState() => _MediaPlayerPreviewState();
}

class _MediaPlayerPreviewState extends State<MediaPlayerPreview> {
  static const _viewType = 'com.backgrounds.trend4k/media_player_preview';

  String? _localPath;

  @override
  void initState() {
    super.initState();
    _resolveLocalFile();
  }

  @override
  void didUpdateWidget(covariant MediaPlayerPreview old) {
    super.didUpdateWidget(old);
    if (old.videoUrl != widget.videoUrl) {
      _localPath = null;
      _resolveLocalFile();
    }
  }

  Future<void> _resolveLocalFile() async {
    try {
      final file =
          await DefaultCacheManager().getSingleFile(widget.videoUrl);
      if (mounted) setState(() => _localPath = file.path);
    } catch (_) {
      // Falls back to streaming the remote URL directly rather than never
      // playing at all.
      if (mounted) setState(() => _localPath = widget.videoUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _localPath;
    // The poster underneath keeps showing until a source is ready - no
    // black frame while the clip downloads.
    if (path == null) return const SizedBox.shrink();
    return AndroidView(
      viewType: _viewType,
      creationParams: {'videoUrl': path},
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
