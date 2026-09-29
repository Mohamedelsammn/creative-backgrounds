import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Root-cause regression test for "Wallpaper Only still shows a clock" on
/// LIVE/VIDEO (and, latently, STANDARD/DEPTH) wallpapers.
///
/// The Dart side was already correct and is covered by
/// `live_video_clock_apply_test.dart` / `apply_design_choice_test.dart`:
/// choosing "Wallpaper Only" makes `_ApplySheetState.clockConfig` null, and
/// that null is serialized as a genuinely null `clockConfig` argument over
/// the platform channel - never an empty/default JSON string.
///
/// The actual bug lived entirely in native code, one call deeper than any
/// existing test reached: `ClockConfig.fromJson(null)` - called by both
/// `VideoWallpaperService.startPlayback()` and
/// `LiveWallpaperService.currentConfig()` whenever no config was persisted -
/// fell back to `ClockConfig()`, whose `enabled` field defaults to `true`.
/// So "no clock was ever sent" silently became "draw the default clock",
/// exactly the `clockConfig ?: ClockConfig.default()`-equivalent pattern the
/// fix must not use. `ClockRenderer.render`/`GLVideoClockCompositor
/// .drawClockQuad` both correctly gate on `config.enabled`, so the bug was
/// never in the renderers - it was one layer earlier, in what "no config"
/// deserializes to.
///
/// There is no Kotlin test harness in this project (no JUnit dependency, no
/// `android/app/src/test/`) - adding one is out of scope for a targeted bug
/// fix. These are source-guard tests, the same pattern already established
/// by `clock_hour_zero_padding_test.dart`'s "native (Kotlin) contract stays
/// in sync" group: they assert on the actual shipped source text of the
/// fix, not a re-implementation of it, so a regression that reintroduces
/// the old fallback is caught here even without a native test runner.
void main() {
  late String clockConfigSource;

  setUpAll(() {
    clockConfigSource = File(
      'android/app/src/main/kotlin/com/backgrounds/trend4k/ClockConfig.kt',
    ).readAsStringSync();
  });

  group('ClockConfig.fromJson(null) - the shared root cause', () {
    test(
        'a null/empty json string resolves to a DISABLED config, not the '
        'enabled-by-default constructor', () {
      // The exact buggy line was `if (json.isNullOrEmpty()) return
      // ClockConfig()` - that bare constructor call defaults `enabled` to
      // true. The fix must route the null/empty branch through a named,
      // explicitly-disabled value instead.
      final fromJsonBlock = _extractFunction(clockConfigSource, 'fromJson');
      expect(
        fromJsonBlock.contains('return ClockConfig()'),
        isFalse,
        reason: 'the null/empty branch of fromJson must never return the '
            'bare, enabled-by-default ClockConfig() - that is exactly what '
            'made "no clock configured" render a default clock anyway',
      );
      expect(
        fromJsonBlock.contains('isNullOrEmpty()) return DISABLED') ||
            RegExp(r'isNullOrEmpty\(\)\)\s*return\s+\w*DISABLED')
                .hasMatch(fromJsonBlock),
        isTrue,
        reason: 'the null/empty branch must return an explicitly-disabled '
            'ClockConfig, so a wallpaper with no persisted clock config '
            'never draws one',
      );
    });

    test('the DISABLED default itself has enabled == false', () {
      expect(
        RegExp(r'DISABLED\s*=\s*ClockConfig\(enabled\s*=\s*false\)')
            .hasMatch(clockConfigSource),
        isTrue,
        reason: 'DISABLED must construct enabled=false explicitly - relying '
            'on some other implicit default here would silently break the '
            'moment ClockConfig\'s own default for `enabled` ever changes',
      );
    });

    test(
        'ClockRenderer and GLVideoClockCompositor still gate on '
        'config.enabled before drawing (the renderers were never the bug, '
        'but the fix depends on them actually honoring DISABLED)', () {
      final rendererSource = File(
        'android/app/src/main/kotlin/com/backgrounds/trend4k/ClockRenderer.kt',
      ).readAsStringSync();
      expect(
        rendererSource.contains('!config.enabled'),
        isTrue,
        reason: 'ClockRenderer.render must bail out when the resolved '
            'config is disabled, or a correctly-disabled DISABLED value '
            'would still get drawn',
      );

      final compositorSource = File(
        'android/app/src/main/kotlin/com/backgrounds/trend4k/GLVideoClockCompositor.kt',
      ).readAsStringSync();
      expect(
        compositorSource.contains('!clockConfig.enabled'),
        isTrue,
        reason: 'the video compositor\'s drawClockQuad must bail out on a '
            'disabled config too, for the same reason',
      );
    });

    test(
        'VideoWallpaperService computes hasClock from the resolved config, '
        'so a Wallpaper-Only apply (null clockConfigJson -> DISABLED) takes '
        'the plain MediaPlayer path and skips the compositor entirely '
        '(satisfies "skip the clock rendering work", not just hide it)', () {
      final source = File(
        'android/app/src/main/kotlin/com/backgrounds/trend4k/VideoWallpaperService.kt',
      ).readAsStringSync();
      expect(
        source.contains('val hasClock = clockConfig.enabled'),
        isTrue,
        reason: 'hasClock must be derived from the parsed config\'s own '
            'enabled flag - with the fromJson fix, a Wallpaper-Only apply '
            'now correctly resolves hasClock to false',
      );
    });
  });

  group('sibling configs already modeled absence correctly (contrast case)', () {
    test(
        'StudioDateConfig.fromJson(null) returns null, not a default '
        'enabled instance - this class was never buggy', () {
      final source = File(
        'android/app/src/main/kotlin/com/backgrounds/trend4k/StudioDateConfig.kt',
      ).readAsStringSync();
      expect(
        RegExp(r'isNullOrBlank\(\)\)\s*return\s+null').hasMatch(source),
        isTrue,
      );
    });

    test(
        'StudioWidgetConfig.listFromJson(null) returns an empty list, not '
        'a default widget set - this class was never buggy either', () {
      final source = File(
        'android/app/src/main/kotlin/com/backgrounds/trend4k/StudioWidgetConfig.kt',
      ).readAsStringSync();
      expect(
        RegExp(r'isNullOrBlank\(\)\)\s*return\s+emptyList\(\)').hasMatch(source),
        isTrue,
      );
    });
  });
}

/// Extracts the source text of a single named function from a Kotlin file,
/// from its `fun <name>(` line up to the matching closing brace (by simple
/// brace-depth counting - sufficient for this file's straightforward
/// control flow, not a general Kotlin parser).
String _extractFunction(String source, String name) {
  final startMatch = RegExp('fun $name\\(').firstMatch(source);
  expect(
    startMatch,
    isNotNull,
    reason: 'expected a `fun $name(` in the source',
  );
  final start = startMatch!.start;
  var depth = 0;
  var seenOpenBrace = false;
  for (var i = start; i < source.length; i++) {
    final ch = source[i];
    if (ch == '{') {
      depth++;
      seenOpenBrace = true;
    } else if (ch == '}') {
      depth--;
      if (seenOpenBrace && depth == 0) {
        return source.substring(start, i + 1);
      }
    }
  }
  fail('unterminated function body for $name');
}
