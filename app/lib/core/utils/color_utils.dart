/// Parses an API hex color string like "#F5A623" or "F5A623" (optionally with
/// alpha, "#AARRGGBB") into an opaque ARGB int. Returns null on bad input so
/// callers can fall back to a themed default.
int? parseHexColorToArgb(String? hex) {
  if (hex == null) return null;
  var value = hex.trim().replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value'; // add opaque alpha
  if (value.length != 8) return null;
  return int.tryParse(value, radix: 16);
}

/// Parses a CSS-style hex color from the API — `#RRGGBB` or `#RRGGBBAA` — into
/// an ARGB int.
///
/// This differs from [parseHexColorToArgb] in the byte order of the 8-digit
/// form: the backend follows the CSS convention where alpha comes **last**
/// (`#RRGGBBAA`), whereas [parseHexColorToArgb] reads the Android/Flutter
/// convention where it comes first (`#AARRGGBB`). Using the wrong one turns a
/// fully opaque white into a transparent red, so clock colors (which the
/// dashboard authors as CSS) must come through here.
///
/// Returns null on bad input so callers fall back to a safe default.
int? parseCssHexColorToArgb(String? hex) {
  if (hex == null) return null;
  final value = hex.trim().replaceFirst('#', '');
  if (value.length == 6) {
    final rgb = int.tryParse(value, radix: 16);
    return rgb == null ? null : 0xFF000000 | rgb;
  }
  if (value.length == 8) {
    final rgba = int.tryParse(value, radix: 16);
    if (rgba == null) return null;
    final alpha = rgba & 0xFF;
    final rgb = (rgba >> 8) & 0xFFFFFF;
    return (alpha << 24) | rgb;
  }
  return null;
}

/// Serializes an ARGB int back to the CSS `#RRGGBBAA` form the API expects.
/// Opaque colors are emitted as the shorter `#RRGGBB`.
String argbToCssHex(int argb) {
  final alpha = (argb >> 24) & 0xFF;
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  if (alpha == 0xFF) return '#$rgb';
  return '#$rgb${alpha.toRadixString(16).padLeft(2, '0')}';
}
