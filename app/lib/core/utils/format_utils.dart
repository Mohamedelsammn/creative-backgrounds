/// Human-readable byte size, e.g. 44040192 → "42 MB".
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  const units = ['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final rounded = unit >= 2 ? size.round() : size.toStringAsFixed(0);
  return '$rounded ${units[unit]}';
}
