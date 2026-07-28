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
