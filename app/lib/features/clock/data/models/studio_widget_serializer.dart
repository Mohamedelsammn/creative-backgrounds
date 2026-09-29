import 'dart:convert';

import '../../domain/entities/studio_design_entity.dart';

/// Serializes [StudioWidget]s for the native renderers.
///
/// The native side parses this with `StudioWidgetConfig.listFromJson`, so the
/// two must agree on key names and value shapes. Colours cross as ARGB ints -
/// already converted from the backend's CSS `#RRGGBBAA` byte order by
/// `StudioDesignMapper` - so native never re-parses a colour string and the
/// two sides cannot disagree about byte order.
///
/// Only widget kinds this build can actually draw are emitted; an unsupported
/// kind was already dropped at parse time.
class StudioWidgetSerializer {
  const StudioWidgetSerializer._();

  /// Encodes [widgets] as a JSON array, or null when there is nothing to draw.
  ///
  /// Null (rather than `"[]"`) lets the apply path clear any previously
  /// applied widgets with the same value it uses for "none".
  static String? toJson(List<StudioWidget> widgets) {
    if (widgets.isEmpty) return null;
    final encodable = widgets.map(_one).whereType<Map<String, Object?>>();
    if (encodable.isEmpty) return null;
    return jsonEncode(encodable.toList());
  }

  /// Encodes the independently-positioned date element, or null when there is
  /// nothing to draw. Null is also what CLEARS a previously applied one.
  static String? dateToJson(StudioDateWidget? date) {
    if (date == null || !date.enabled) return null;
    return jsonEncode({
      'enabled': true,
      'format': date.format,
      'pattern': date.pattern,
      'locale': date.locale,
      'customX': date.customX,
      'customY': date.customY,
      'position': date.position,
      'color': date.color,
      'scale': date.scale,
      'font': date.font,
      'weight': date.weight,
      'uppercase': date.uppercase,
    });
  }

  static Map<String, Object?>? _one(StudioWidget widget) => switch (widget) {
        StudioBatteryRing() => {
            'kind': 'batteryRing',
            'customX': widget.customX,
            'customY': widget.customY,
            'color': widget.color,
            'scale': widget.scale,
            'rotation': widget.rotation,
            'anchor': widget.anchor,
            'showPercentage': widget.showPercentage,
          },
      };
}
