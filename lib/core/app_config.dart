import 'package:flutter/services.dart' show appFlavor;

/// Версия приложения (Android flavor).
///
/// * `online`  — распознавание через внешний AI (Gemini бесплатно или Claude).
/// * `offline` — своя модель в телефоне + своя база болезней, без интернета.
enum AppEdition { online, offline }

class AppConfig {
  const AppConfig(this.edition);

  final AppEdition edition;

  bool get isOffline => edition == AppEdition.offline;

  /// Для сборок без flavor (iOS): `--dart-define=EDITION=offline`.
  static const _definedEdition = String.fromEnvironment('EDITION');

  /// По умолчанию (тесты, сборка без --flavor и без EDITION) — online.
  static AppConfig fromFlavor([String? flavor]) {
    final f = flavor ?? appFlavor ?? (_definedEdition.isEmpty ? null : _definedEdition);
    return AppConfig(f == 'offline' ? AppEdition.offline : AppEdition.online);
  }
}
