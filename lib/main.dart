import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_scope.dart';
import 'data/local/local_store.dart';
import 'data/repositories/farm_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'features/knowledge/crop_guide.dart';
import 'services/ai_service.dart';
import 'services/backup_service.dart';
import 'services/notification_service.dart';

/// Оғози барнома.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await bootstrap();
  runApp(AgroApp(services: services));
}

Future<AppServices> bootstrap({LocalStore? store, NotificationService? notifications}) async {
  final st = store ?? await FileStore.open();
  final farm = FarmRepository(st);
  final settings = SettingsRepository(st);
  final notif = notifications ?? LocalNotificationService();
  final results = await Future.wait([
    farm.load(),
    settings.load(),
    KnowledgeBase.load(),
    notif.init(),
  ]);
  return AppServices(
    farm: farm,
    settings: settings,
    ai: AiService(),
    notifications: notif,
    backup: BackupService(),
    knowledge: results[2] as KnowledgeBase,
  );
}
