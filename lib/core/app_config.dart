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

  /// По умолчанию (тесты, сборка без --flavor) — online.
  static AppConfig fromFlavor([String? flavor]) =>
      AppConfig((flavor ?? appFlavor) == 'offline' ? AppEdition.offline : AppEdition.online);
}
