import 'package:flutter/widgets.dart';

import '../data/repositories/farm_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../features/knowledge/crop_guide.dart';
import '../services/ai_service.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';

/// Ҳамаи хидматҳои барнома дар як ҷо.
class AppServices {
  AppServices({
    required this.farm,
    required this.settings,
    required this.ai,
    required this.notifications,
    required this.backup,
    required this.knowledge,
  });

  final FarmRepository farm;
  final SettingsRepository settings;
  final AiService ai;
  final NotificationService notifications;
  final BackupService backup;
  final KnowledgeBase knowledge;
}

/// Дастрасӣ ба [AppServices] аз ҳар виҷет: `AppScope.of(context)`.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope дар дарахти виҷетҳо нест');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
