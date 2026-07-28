import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../storage/hive_storage.dart';
import '../storage/storage_keys.dart';

/// App-root cubit holding the active [Locale]. Rebuilds `MaterialApp` on change.
/// The persisted value lives in the Hive `settings` box so Settings and this
/// cubit stay in sync. Full ARB localization is wired in Phase 18.
class LocaleCubit extends Cubit<Locale> {
  LocaleCubit(this._storage) : super(_initial(_storage));

  final HiveStorage _storage;

  static const supportedLocales = [Locale('en'), Locale('ar')];

  static Locale _initial(HiveStorage storage) {
    final code = storage.read<String>(HiveBoxes.settings, StorageKeys.language);
    return Locale(code == 'ar' ? 'ar' : 'en');
  }

  void setLocale(String languageCode) {
    _storage.write(HiveBoxes.settings, StorageKeys.language, languageCode);
    emit(Locale(languageCode));
  }
}
