/// A dotted version string (e.g. "5.0.1"), comparable field-by-field.
///
/// Deliberately not the `pub_semver` package: that's a transitive dev
/// dependency here, not a direct one, and this app only ever needs to
/// compare two plain `major.minor.patch`-shaped strings - a small hand-rolled
/// comparator avoids adding a new direct dependency for that.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.parts);

  final List<int> parts;

  /// Parses a version string like "5.0.1" (or "5.0.1+45" - the build number
  /// suffix, if present, is discarded since it's not part of the semantic
  /// version users/stores compare). Non-numeric or missing segments become 0
  /// rather than throwing, so a malformed string degrades to "very old"
  /// instead of crashing the version check.
  factory AppVersion.parse(String raw) {
    final withoutBuild = raw.split('+').first;
    final segments = withoutBuild.split('.');
    final parts = segments.map((s) => int.tryParse(s.trim()) ?? 0).toList();
    return AppVersion(parts);
  }

  int _at(int index) => index < parts.length ? parts[index] : 0;

  @override
  int compareTo(AppVersion other) {
    final length = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < length; i++) {
      final cmp = _at(i).compareTo(other._at(i));
      if (cmp != 0) return cmp;
    }
    return 0;
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator <=(AppVersion other) => compareTo(other) <= 0;
  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator >=(AppVersion other) => compareTo(other) >= 0;

  @override
  String toString() => parts.join('.');
}
