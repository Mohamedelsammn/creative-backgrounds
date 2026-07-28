part of 'settings_bloc.dart';

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class SettingsLoadRequested extends SettingsEvent {
  const SettingsLoadRequested();
}

class SettingsLanguageChanged extends SettingsEvent {
  const SettingsLanguageChanged(this.language);

  final String language;

  @override
  List<Object?> get props => [language];
}

class SettingsClearCacheRequested extends SettingsEvent {
  const SettingsClearCacheRequested();
}
