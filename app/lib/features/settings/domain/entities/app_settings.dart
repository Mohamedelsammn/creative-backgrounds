import 'package:equatable/equatable.dart';

class AppSettings extends Equatable {
  const AppSettings({
    required this.language,
    required this.cachedSizeBytes,
    required this.appVersion,
  });

  final String language; // 'en' | 'ar'
  final int cachedSizeBytes;
  final String appVersion;

  AppSettings copyWith({
    String? language,
    int? cachedSizeBytes,
    String? appVersion,
  }) {
    return AppSettings(
      language: language ?? this.language,
      cachedSizeBytes: cachedSizeBytes ?? this.cachedSizeBytes,
      appVersion: appVersion ?? this.appVersion,
    );
  }

  @override
  List<Object?> get props => [
        language,
        cachedSizeBytes,
        appVersion,
      ];
}
