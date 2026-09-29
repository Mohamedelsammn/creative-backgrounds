import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The APPLIED wallpaper's clock is drawn by native Kotlin
/// (`ClockRenderer.kt`), not by Flutter - so fixing only the Dart preview
/// would leave an Arabic device still rendering Arabic-Indic digits onto the
/// real home screen.
///
/// There is no Dart-side seam to assert that through, so this guards the
/// native source directly: the renderer must format with an explicitly
/// pinned locale and must never reach for the device default.
void main() {
  final renderer = File(
    'android/app/src/main/kotlin/com/backgrounds/trend4k/ClockRenderer.kt',
  );

  late String source;

  /// Kotlin source with comments removed, so a doc comment that merely
  /// *mentions* `Locale.getDefault()` (explaining why it must not be used)
  /// is not mistaken for a real call.
  String stripComments(String kotlin) => kotlin
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .split('\n')
      .map((line) {
        final idx = line.indexOf('//');
        return idx == -1 ? line : line.substring(0, idx);
      })
      .join('\n');

  setUpAll(() {
    expect(
      renderer.existsSync(),
      isTrue,
      reason: 'ClockRenderer.kt not found at ${renderer.path} - if the file '
          'moved, update this guard rather than deleting it',
    );
    source = renderer.readAsStringSync();
  });

  test('the native clock renderer never formats with the device locale', () {
    expect(
      stripComments(source).contains('Locale.getDefault()'),
      isFalse,
      reason: 'Locale.getDefault() reintroduces Arabic-Indic digits into the '
          'applied wallpaper on an Arabic device - format with Locale.US',
    );
  });

  test('the native clock renderer pins an explicit artwork locale', () {
    expect(source, contains('Locale.US'));
  });

  test('every SimpleDateFormat call passes the pinned locale', () {
    final calls = RegExp(r'SimpleDateFormat\([^)]*\)').allMatches(source);
    expect(
      calls,
      isNotEmpty,
      reason: 'expected the renderer to still format time/date here',
    );
    for (final call in calls) {
      expect(
        call.group(0),
        contains('artworkLocale'),
        reason: '${call.group(0)} must format with the pinned artwork locale',
      );
    }
  });

  test(
    'the three native renderers all share this one ClockRenderer, so the fix '
    'covers static/depth, video and GL-composited clock paths alike',
    () {
      for (final path in const [
        'android/app/src/main/kotlin/com/backgrounds/trend4k/LiveWallpaperService.kt',
        'android/app/src/main/kotlin/com/backgrounds/trend4k/VideoWallpaperService.kt',
        'android/app/src/main/kotlin/com/backgrounds/trend4k/GLVideoClockCompositor.kt',
      ]) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path missing');
        expect(
          file.readAsStringSync(),
          contains('ClockRenderer'),
          reason: '$path should render its clock through the shared '
              'ClockRenderer, not its own formatter',
        );
      }
    },
  );

  test('no other native file formats dates with the device locale', () {
    final dir = Directory('android/app/src/main/kotlin');
    final offenders = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.kt'))
        .where(
          (f) => stripComments(f.readAsStringSync())
              .contains('Locale.getDefault()'),
        )
        .map((f) => f.path)
        .toList();
    expect(
      offenders,
      isEmpty,
      reason: 'these native files format with the device locale: $offenders',
    );
  });
}
