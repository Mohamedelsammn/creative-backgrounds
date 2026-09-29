import 'dart:convert';
import 'dart:io';

import 'package:creativebackground/features/clock/data/models/studio_design_mapper.dart';
import 'package:creativebackground/features/clock/data/models/studio_widget_serializer.dart';
import 'package:creativebackground/features/clock/domain/entities/studio_design_entity.dart';
import 'package:creativebackground/features/clock/presentation/widgets/date_widget_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// `studio.dateWidget` - an element the backend actually authors (3 production
/// wallpapers enable it) and which previously rendered nowhere.
///
/// It is SEPARATE from the clock's own nested `date`: it carries its own
/// coordinates, font, scale and uppercase rule, and production data enables at
/// most one of the two per wallpaper.
void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Map<String, dynamic> fixture(String name) =>
      jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  group('the real Porshe dateWidget', () {
    late StudioDateWidget date;

    setUpAll(() {
      final f = fixture('studio_battery_ring');
      date = StudioDesignMapper.fromJson(f['studio'])!.dateWidget!;
    });

    test('is enabled and independently positioned', () {
      expect(date.enabled, isTrue);
      expect(date.customX, closeTo(0.3, 1e-9));
      expect(date.customY, closeTo(0.24, 1e-9));
      expect(date.hasCustomPosition, isTrue);
    });

    test('carries its authored styling', () {
      expect(date.format, 'short');
      expect(date.scale, closeTo(0.8, 1e-9));
      expect(date.font, 'Inter');
      expect(date.weight, 400);
      expect(date.uppercase, isFalse);
      expect(date.color, 0xFFFFFFFF);
      expect(date.locale, 'en');
    });

    test('sits BELOW the clock, not on top of it', () {
      final f = fixture('studio_battery_ring');
      final design = StudioDesignMapper.fromJson(f['studio'])!;
      expect(design.clock!.customY, lessThan(date.customY!));
    });

    test('the clock\'s own nested date stays OFF, so nothing duplicates', () {
      final f = fixture('studio_battery_ring');
      final design = StudioDesignMapper.fromJson(f['studio'])!;
      expect(design.clock!.showDate, isFalse);
    });
  });

  group('formatting matches the native renderer', () {
    // `StudioDateRenderer.patternFor` in Kotlin repeats these ids.
    test('every format id maps to a pattern', () {
      expect(StudioDateFormats.patternFor('short'), 'MMM d');
      expect(StudioDateFormats.patternFor('long'), 'EEEE, MMMM d');
      expect(StudioDateFormats.patternFor('medium'), 'MMM d, yyyy');
    });

    test('an unknown format falls back to medium', () {
      expect(StudioDateFormats.patternFor('galactic'), 'MMM d, yyyy');
    });

    test('uppercase is applied when authored', () {
      final date = DateTime(2026, 11, 10);
      const plain = StudioDateWidget(enabled: true, format: 'short');
      const upper =
          StudioDateWidget(enabled: true, format: 'short', uppercase: true);
      expect(StudioDateFormats.format(plain, date), 'Nov 10');
      expect(StudioDateFormats.format(upper, date), 'NOV 10');
    });

    test('an authored pattern overrides the format id', () {
      const custom =
          StudioDateWidget(enabled: true, format: 'short', pattern: 'yyyy');
      expect(StudioDateFormats.format(custom, DateTime(2026, 1, 1)), '2026');
    });

    test('the long format renders a full weekday and month', () {
      const long = StudioDateWidget(enabled: true, format: 'long');
      expect(
        StudioDateFormats.format(long, DateTime(2026, 11, 10)),
        'Tuesday, November 10',
      );
    });
  });

  group('custom format: the README\'s documented date-fns tokens', () {
    // Frozen instant: Tuesday 2026-11-10. Every case below is one of the
    // README's own worked examples for `studio.dateWidget.format: "custom"`
    // + `pattern` - confirmed byte-identical between date-fns' documented
    // tokens and `intl`'s `DateFormat` ICU tokens for exactly these six
    // patterns, so no new parser is needed; `StudioDateFormats.format`
    // already applies `pattern ?? patternFor(format)`, which already prefers
    // an authored pattern unconditionally.
    final frozen = DateTime(2026, 11, 10);

    StudioDateWidget customPattern(String pattern) => StudioDateWidget(
          enabled: true,
          format: 'custom',
          pattern: pattern,
        );

    test('EEEE, d MMMM yyyy - full weekday, day, month, year', () {
      expect(
        StudioDateFormats.format(
          customPattern('EEEE, d MMMM yyyy'),
          frozen,
        ),
        'Tuesday, 10 November 2026',
      );
    });

    test('d MMMM yyyy - day, full month, year', () {
      expect(
        StudioDateFormats.format(customPattern('d MMMM yyyy'), frozen),
        '10 November 2026',
      );
    });

    test('d MMM yyyy - day, abbreviated month, year', () {
      expect(
        StudioDateFormats.format(customPattern('d MMM yyyy'), frozen),
        '10 Nov 2026',
      );
    });

    test('MMMM yyyy - full month and year, no day', () {
      expect(
        StudioDateFormats.format(customPattern('MMMM yyyy'), frozen),
        'November 2026',
      );
    });

    test('yyyy-MM-dd - ISO date', () {
      expect(
        StudioDateFormats.format(customPattern('yyyy-MM-dd'), frozen),
        '2026-11-10',
      );
    });

    test('yyyy - year only', () {
      expect(
        StudioDateFormats.format(customPattern('yyyy'), frozen),
        '2026',
      );
    });

    test('a year-bearing custom pattern still honours uppercase', () {
      final upper = StudioDateWidget(
        enabled: true,
        format: 'custom',
        pattern: 'EEEE, d MMMM yyyy',
        uppercase: true,
      );
      expect(
        StudioDateFormats.format(upper, frozen),
        'TUESDAY, 10 NOVEMBER 2026',
      );
    });

    test(
      'a "custom" format id with no pattern falls back to medium, not '
      'literal "custom" text',
      () {
        // A malformed/incomplete authoring - `format: "custom"` but no
        // `pattern` sent - must not crash or pass "custom" itself to
        // DateFormat as if it were a pattern string.
        const malformed = StudioDateWidget(enabled: true, format: 'custom');
        expect(
          StudioDateFormats.format(malformed, frozen),
          'Nov 10, 2026',
        );
      },
    );
  });

  group('serialization to native', () {
    test('an enabled date serializes every authored property', () {
      final f = fixture('studio_battery_ring');
      final date = StudioDesignMapper.fromJson(f['studio'])!.dateWidget;
      final json = StudioWidgetSerializer.dateToJson(date);
      expect(json, isNotNull);
      final decoded = jsonDecode(json!) as Map<String, Object?>;
      expect(decoded['enabled'], isTrue);
      expect(decoded['format'], 'short');
      expect(decoded['customX'], closeTo(0.3, 1e-9));
      expect(decoded['customY'], closeTo(0.24, 1e-9));
      expect(decoded['scale'], closeTo(0.8, 1e-9));
      expect(decoded['color'], 0xFFFFFFFF);
      expect(decoded['weight'], 400);
      expect(decoded['uppercase'], isFalse);
    });

    test('a disabled date serializes to null, which CLEARS a stale one', () {
      expect(
        StudioWidgetSerializer.dateToJson(
          const StudioDateWidget(enabled: false),
        ),
        isNull,
      );
      expect(StudioWidgetSerializer.dateToJson(null), isNull);
    });
  });

  group('hasDesign and classification', () {
    test('an enabled date alone counts as a design', () {
      final d = StudioDesignMapper.fromJson({
        'dateWidget': {'enabled': true},
      })!;
      expect(d.hasDesign, isTrue);
    });

    test('a date-only design is STATIC - it changes at midnight, not live',
        () {
      final d = StudioDesignMapper.fromJson({
        'dateWidget': {'enabled': true},
      })!;
      expect(d.isDynamic, isFalse);
      expect(d.renderMode, DesignRenderMode.static_);
    });

    test('a disabled date is not a design', () {
      final d = StudioDesignMapper.fromJson({
        'dateWidget': {'enabled': false},
      });
      expect(d?.hasDesign ?? false, isFalse);
    });
  });

  group('both apply paths actually send the date to native', () {
    // A regression guard: the static/depth path once serialized the date but
    // never passed it to the channel, so the ring and clock reached the
    // applied wallpaper and the date silently did not.
    test('every applyWallpaper/applyVideoWallpaper call passes it', () {
      final src = File(
        'lib/features/apply_wallpaper/data/repositories/'
        'apply_wallpaper_repository_impl.dart',
      ).readAsStringSync();

      final applyCalls = RegExp(r'_channel\.apply\w*\(').allMatches(src).length;
      final dateArgs =
          RegExp(r'dateWidgetJson:').allMatches(src).length;
      expect(
        dateArgs,
        applyCalls,
        reason: 'every apply call must forward the date element, or it '
            'renders in Details and vanishes once applied',
      );

      // The same rule for the widgets array.
      final widgetArgs = RegExp(r'widgetsJson:').allMatches(src).length;
      expect(widgetArgs, applyCalls);
    });
  });
}
