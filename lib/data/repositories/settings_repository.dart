import 'dart:convert';

import 'package:flutter/material.dart';

import '../local/local_store.dart';

class AppSettings {
  const AppSettings({
    this.languageCode = 'tg',
    this.apiKey = '',
    this.notificationsEnabled = true,
    this.themeMode = ThemeMode.system,
    this.onboarded = false,
  });

  final String languageCode;
  final String apiKey;
  final bool notificationsEnabled;
  final ThemeMode themeMode;
  final bool onboarded;

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  AppSettings copyWith({
    String? languageCode,
    String? apiKey,
    bool? notificationsEnabled,
    ThemeMode? themeMode,
    bool? onboarded,
  }) =>
      AppSettings(
        languageCode: languageCode ?? this.languageCode,
        apiKey: apiKey ?? this.apiKey,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        themeMode: themeMode ?? this.themeMode,
        onboarded: onboarded ?? this.onboarded,
      );

  Map<String, dynamic> toJson() => {
        'languageCode': languageCode,
        'apiKey': apiKey,
        'notificationsEnabled': notificationsEnabled,
        'themeMode': themeMode.name,
        'onboarded': onboarded,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        languageCode: (j['languageCode'] as String?) ?? 'tg',
        apiKey: (j['apiKey'] as String?) ?? '',
        notificationsEnabled: j['notificationsEnabled'] != false,
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == j['themeMode'],
          orElse: () => ThemeMode.system,
        ),
        onboarded: j['onboarded'] == true,
      );
}

/// Танзимот алоҳида аз маълумоти хоҷагӣ нигоҳ дошта мешавад,
/// то калиди API ба нусхаи эҳтиётӣ наафтад.
class SettingsRepository extends ValueNotifier<AppSettings> {
  SettingsRepository(this._store) : super(const AppSettings());

  static const storageKey = 'settings';
  final LocalStore _store;

  Future<void> load() async {
    final raw = await _store.read(storageKey);
    if (raw == null) return;
    try {
      value = AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // танзимоти вайрон — пешфарз
    }
  }

  Future<void> update(AppSettings s) async {
    value = s;
    await _store.write(storageKey, jsonEncode(s.toJson()));
  }
}
