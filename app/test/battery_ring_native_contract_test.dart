import 'dart:io';

import 'package:creativebackground/features/clock/presentation/widgets/battery_ring_widget.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the native half of the batteryRing contract.
///
/// The Android module has no JVM unit-test source set, so - following the same
/// precedent as `clock_native_locale_pinned_test.dart` - these assert
/// invariants of the Kotlin source directly. They are deliberately about
/// things that would silently break parity or leak resources, not about
/// formatting.
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// Strips comments so a doc comment mentioning a term cannot satisfy (or
  /// falsely trip) an assertion about real code.
  String stripComments(String kotlin) => kotlin
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  const renderer =
      'android/app/src/main/kotlin/com/backgrounds/trend4k/BatteryRingRenderer.kt';
  const observer =
      'android/app/src/main/kotlin/com/backgrounds/trend4k/BatteryLevelObserver.kt';
  const live =
      'android/app/src/main/kotlin/com/backgrounds/trend4k/LiveWallpaperService.kt';
  const video =
      'android/app/src/main/kotlin/com/backgrounds/trend4k/VideoWallpaperService.kt';

  group('the native renderer exists and is shared', () {
    test('there is exactly one battery-ring renderer', () {
      expect(File(renderer).existsSync(), isTrue);
    });

    test('every path reaches that one renderer, directly or via the compositor',
        () {
      // One reusable renderer rather than three divergent implementations.
      // The static/depth engine composes it directly; the video engine
      // delegates to `GLVideoClockCompositor`, which composes the same one.
      expect(stripComments(read(live)).contains('BatteryRingRenderer'), isTrue);
      expect(
        stripComments(read(
          'android/app/src/main/kotlin/com/backgrounds/trend4k/GLVideoClockCompositor.kt',
        )).contains('BatteryRingRenderer'),
        isTrue,
      );
      // No second implementation anywhere.
      final all = Directory('android/app/src/main/kotlin')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.kt'))
          .where((f) => stripComments(f.readAsStringSync())
              .contains('class BatteryRingRenderer'));
      expect(all, hasLength(1));
    });

    test('the video path draws the ring onto the same overlay as the clock',
        () {
      final src = stripComments(read(
        'android/app/src/main/kotlin/com/backgrounds/trend4k/GLVideoClockCompositor.kt',
      ));
      expect(src.contains('ringRenderer.render'), isTrue);
    });
  });

  group('geometry matches the Flutter widget exactly', () {
    // A divergence here means the applied wallpaper stops matching the
    // preview - the exact class of bug this pass exists to remove.
    late String src;
    setUpAll(() => src = stripComments(read(renderer)));

    test('base diameter agrees', () {
      expect(BatteryRingMetrics.baseDiameter, 28);
      expect(src.contains('BASE_DIAMETER = 28f'), isTrue);
    });

    test('base stroke agrees', () {
      expect(BatteryRingMetrics.baseStroke, 2.5);
      expect(src.contains('BASE_STROKE = 2.5f'), isTrue);
    });

    test('the percentage label is drawn BESIDE the ring, not inside it', () {
      // The dashboard's own composited reference draws the "72%" label
      // trailing the ring's right edge, not centred inside the circle.
      expect(BatteryRingMetrics.labelGap, 6);
      expect(src.contains('LABEL_GAP = 6f'), isTrue);
      expect(src.contains('textAlign = Paint.Align.LEFT'), isTrue);
      expect(src.contains('centerX + diameter / 2f + gap'), isTrue);
    });

    test('the percentage label includes the % sign', () {
      expect(src.contains('"\$level%"'), isTrue);
    });

    test('track alpha agrees', () {
      expect(BatteryRingMetrics.trackAlpha, 0.25);
      expect(src.contains('TRACK_ALPHA = 0.25f'), isTrue);
    });

    test('the arc starts at 12 o\'clock on both sides', () {
      // Dart uses radians (-pi/2), Android degrees (-90) - the same angle.
      expect(BatteryRingMetrics.startAngle, closeTo(-1.5707963267948966, 1e-12));
      expect(src.contains('START_ANGLE = -90f'), isTrue);
    });

    test('radius is derived the same way', () {
      expect(src.contains('(diameter - stroke) / 2f'), isTrue);
    });

    test('the ring+label row is centred on its point; anchors 20/50/82%', () {
      // FLUTTER_RENDERING_GUIDE §7.2 / §1.
      expect(src.contains('ax = width * cxRaw'), isTrue);
      expect(src.contains('ay = height * cyRaw'), isTrue);
      expect(src.contains('"center" -> 0.5f'), isTrue);
      expect(src.contains('"bottom" -> 0.82f'), isTrue);
      expect(src.contains('else -> 0.2f'), isTrue);
      expect(src.contains('ax - rowWidth / 2f + diameter / 2f'), isTrue);
    });

    test('sizes are proportions of the viewport width, not density', () {
      // W * 0.045 * scale; ring 1.1x; border 0.14x.
      expect(src.contains('width * 0.045f * config.scale'), isTrue);
      expect(src.contains('text * 1.1f'), isTrue);
      expect(src.contains('diameter * 0.14f'), isTrue);
      expect(stripComments(src).contains('displayMetrics.density'), isFalse);
    });


    test('an unknown level draws the track only, never a 0% arc', () {
      expect(src.contains('if (level != null)'), isTrue);
    });
  });

  group('battery observation is event-driven, not polled', () {
    late String src;
    setUpAll(() => src = stripComments(read(observer)));

    test('it listens for the system battery broadcast', () {
      expect(src.contains('ACTION_BATTERY_CHANGED'), isTrue);
    });

    test('it does NOT poll on a timer', () {
      for (final banned in ['postDelayed', 'Timer(', 'scheduleAtFixedRate']) {
        expect(
          src.contains(banned),
          isFalse,
          reason: 'battery level must come from events, not a $banned loop',
        );
      }
    });

    test('it requests no permission', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      for (final dangerous in [
        'BATTERY_STATS',
        'ACCESS_FINE_LOCATION',
        'ACCESS_COARSE_LOCATION',
      ]) {
        expect(
          manifest.contains(dangerous),
          isFalse,
          reason: 'the battery ring must not need $dangerous',
        );
      }
    });

    test('it only redraws when the level actually changed', () {
      // ACTION_BATTERY_CHANGED also fires for temperature and plug events.
      expect(src.contains('if (next == level) return false'), isTrue);
    });
  });

  group('lifecycle: registered while needed, released when not', () {
    test('both paths stop observing when the wallpaper goes off-screen', () {
      for (final path in [live, video]) {
        final src = stripComments(read(path));
        expect(
          RegExp(r'battery\.stop\(\)').allMatches(src).length,
          greaterThanOrEqualTo(2),
          reason: '$path must stop on both hide and destroy',
        );
      }
    });

    test('both paths release the receiver on destroy', () {
      for (final path in [live, video]) {
        final src = stripComments(read(path));
        final destroy = src.substring(src.indexOf('override fun onDestroy'));
        expect(
          destroy.contains('battery.stop()'),
          isTrue,
          reason: '$path must unregister on destroy, or the receiver leaks',
        );
      }
    });

    test('the observer unregisters defensively', () {
      final src = stripComments(read(observer));
      expect(src.contains('unregisterReceiver'), isTrue);
      // Unregistering an already-unregistered receiver throws; it must not.
      expect(src.contains('runCatching { context.unregisterReceiver'), isTrue);
    });

    test('a wallpaper with no ring never observes the battery at all', () {
      for (final path in [live, video]) {
        final src = stripComments(read(path));
        expect(
          src.contains('is StudioWidgetConfig.BatteryRing'),
          isTrue,
          reason: '$path must gate observation on actually having a ring',
        );
      }
    });
  });

  group('depth z-order is not regressed', () {
    late String src;
    setUpAll(() => src = stripComments(read(live)));

    test('DEPTH order: foreground, clock, foreground at (1 - depth), extras',
        () {
      // FLUTTER_RENDERING_GUIDE §2: the date widget and extras sit ON TOP of
      // the subject; only the clock is occluded, by the (1 - depth) copy.
      final firstFg = src.indexOf('DepthCompositor.drawForeground');
      final clock = src.indexOf('renderer.render(');
      final secondFg = src.indexOf('DepthCompositor.drawForeground', firstFg + 1);
      final ring = src.indexOf('ringRenderer.render');
      expect(firstFg, greaterThan(0));
      expect(clock, greaterThan(firstFg));
      expect(secondFg, greaterThan(clock));
      expect(ring, greaterThan(secondFg));
      expect(src.contains('1f - config.depth'), isTrue);
    });

    test('the ring is drawn AFTER the clock, matching DesignOverlay', () {
      final clock = src.indexOf('renderer.render(');
      final ring = src.indexOf('ringRenderer.render');
      expect(clock, greaterThan(0));
      expect(ring, greaterThan(clock));
    });

    test('the ring composes against the visible viewport, not the surface', () {
      // Preserves the ColorOS oversized-surface fix: a normalized coordinate
      // resolved against a 2340-wide surface instead of the 1080-wide viewport
      // lands half a screen away.
      final ring = src.indexOf('ringRenderer.render');
      final translate = src.indexOf('canvas.translate(viewport.left');
      final restore = src.indexOf('canvas.restore()', ring);
      expect(translate, greaterThan(0));
      expect(translate, lessThan(ring),
          reason: 'the ring must be inside the viewport translate');
      expect(restore, greaterThan(ring));
      expect(src.contains('viewport.width()'), isTrue);
    });
  });

  group('the applied design cannot go stale', () {
    test('the static path always writes the widgets key, even when null', () {
      final src = stripComments(read(
        'android/app/src/main/kotlin/com/backgrounds/trend4k/channels/WallpaperChannel.kt',
      ));
      // Always written, so a ring from a previous wallpaper cannot survive
      // onto one that authored none (or onto a Wallpaper Only apply).
      expect(src.contains('KEY_WIDGETS_JSON, widgets'), isTrue);
    });

    test('the video overlay cache key includes the battery level', () {
      final src = stripComments(read(
        'android/app/src/main/kotlin/com/backgrounds/trend4k/GLVideoClockCompositor.kt',
      ));
      // Without this the ring would freeze at its first value.
      expect(src.contains(r'$batteryLevel'), isTrue);
    });

    test('widgets are read outside the asset-signature guard', () {
      final src = stripComments(read(live));
      final widgets = src.indexOf('StudioWidgetConfig.listFromJson');
      final guard = src.indexOf('if (signature == loadedSignature');
      expect(widgets, greaterThan(0));
      expect(guard, greaterThan(0));
      expect(widgets, lessThan(guard),
          reason: 'a design change with identical bitmaps must still apply');
    });
  });
}
