import 'dart:convert';
import 'dart:io';

import 'package:creativebackground/features/clock/data/models/studio_design_mapper.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:creativebackground/features/clock/presentation/widgets/battery_ring_widget.dart';
import 'package:creativebackground/features/clock/presentation/widgets/clock_renderer_widget.dart';
import 'package:creativebackground/features/clock/presentation/widgets/design_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stage 5/7: Details renders the authored design, using the same
/// [StudioDesign] the apply pipeline serializes to the native renderers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The battery channel is a platform call; stub it so the widget can render
  // in a test without a device.
  const channel = MethodChannel('com.backgrounds.trend4k/battery');
  int? stubbedLevel = 80;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'level' ? stubbedLevel : null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pump(WidgetTester tester, StudioDesign design) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.blue),
                DesignOverlay(design: design),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  StudioDesign designFrom(Map<String, dynamic> studio) =>
      StudioDesignMapper.fromJson(studio)!;

  group('what the overlay renders', () {
    testWidgets('an enabled clock renders a clock', (tester) async {
      await pump(
        tester,
        designFrom({
          'clock': {'enabled': true, 'sizePx': 64},
        }),
      );
      expect(find.byType(ClockRendererWidget), findsOneWidget);
    });

    testWidgets('a clock authored OFF renders nothing', (tester) async {
      await pump(
        tester,
        designFrom({
          'clock': {'enabled': false},
        }),
      );
      expect(find.byType(ClockRendererWidget), findsNothing);
      expect(find.byType(BatteryRingWidget), findsNothing);
    });

    testWidgets('a batteryRing renders a ring', (tester) async {
      await pump(
        tester,
        designFrom({
          'widgets': [
            {'kind': 'batteryRing', 'customX': 0.8, 'customY': 0.13},
          ],
        }),
      );
      expect(find.byType(BatteryRingWidget), findsOneWidget);
    });

    testWidgets('a clock and a ring render together', (tester) async {
      await pump(
        tester,
        designFrom({
          'clock': {'enabled': true},
          'widgets': [
            {'kind': 'batteryRing'},
          ],
        }),
      );
      expect(find.byType(ClockRendererWidget), findsOneWidget);
      expect(find.byType(BatteryRingWidget), findsOneWidget);
    });

    testWidgets('an unknown widget kind renders nothing and does not throw',
        (tester) async {
      await pump(
        tester,
        designFrom({
          'widgets': [
            {'kind': 'somethingFromTheFuture'},
          ],
        }),
      );
      expect(find.byType(BatteryRingWidget), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the overlay never intercepts taps', (tester) async {
      // The design sits above the wallpaper but must not swallow a tap meant
      // for the buttons layered over it.
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => tapped = true,
                  child: const ColoredBox(color: Colors.blue),
                ),
                DesignOverlay(
                  design: designFrom({
                    'clock': {'enabled': true},
                  }),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tapAt(const Offset(200, 400));
      expect(tapped, isTrue);
    });
  });

  group('the real Bunny design renders its authored values', () {
    testWidgets('Bunny renders a clock through the overlay', (tester) async {
      final raw = File('test/fixtures/bunny_clock_config.json')
          .readAsStringSync();
      final design = StudioDesignMapper.fromJson(
        null,
        legacyClockConfig: jsonDecode(raw),
      )!;

      await pump(tester, design);

      expect(find.byType(ClockRendererWidget), findsOneWidget);
      final widget = tester.widget<ClockRendererWidget>(
        find.byType(ClockRendererWidget),
      );
      // The overlay must hand the renderer the AUTHORED config, unmodified -
      // this is the Details half of "Details shows what gets applied".
      expect(widget.config.sizePx, 208);
      expect(widget.config.timeLayout.name, 'stackedCompact');
      expect(widget.config.minutesColor, 0xFFE65100);
      expect(widget.config.font.name, 'oswald');
      expect(widget.config.style.name, 'monument');
      expect(tester.takeException(), isNull);
    });
  });

  group('displayScale', () {
    testWidgets('is forwarded to the clock renderer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesignOverlay(
              design: designFrom({
                'clock': {'enabled': true},
              }),
              displayScale: 0.25,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<ClockRendererWidget>(find.byType(ClockRendererWidget))
            .displayScale,
        0.25,
      );
    });

    testWidgets('is forwarded to the battery ring', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesignOverlay(
              design: designFrom({
                'widgets': [
                  {'kind': 'batteryRing'},
                ],
              }),
              displayScale: 0.5,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<BatteryRingWidget>(find.byType(BatteryRingWidget))
            .displayScale,
        0.5,
      );
    });
  });

  group('battery ring resilience', () {
    testWidgets('an unavailable battery level still renders', (tester) async {
      stubbedLevel = null;
      await pump(
        tester,
        designFrom({
          'widgets': [
            {'kind': 'batteryRing'},
          ],
        }),
      );
      expect(find.byType(BatteryRingWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
      stubbedLevel = 80;
    });

    testWidgets('a platform failure does not break the wallpaper',
        (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'boom'),
      );
      await pump(
        tester,
        designFrom({
          'widgets': [
            {'kind': 'batteryRing'},
          ],
        }),
      );
      expect(find.byType(BatteryRingWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
