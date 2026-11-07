import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_config.dart';
import 'core/app_scope.dart';
import 'data/local/farm_store.dart';
import 'data/local/farm_store_factory.dart';
import 'data/local/local_store.dart';
import 'data/repositories/farm_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'features/knowledge/crop_guide.dart';
import 'services/ai_service.dart';
import 'services/backup_service.dart';
import 'services/error_log.dart';
import 'services/weather_service.dart';
import 'services/notification_service.dart';
import 'services/offline/disease_base.dart';
import 'services/offline/offline_diagnoser.dart';
import 'services/offline/plant_classifier.dart';

/// Оғози барнома.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ErrorLog.instance.init();

  // Любая ошибка записывается в журнал, приложение не закрывается.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorLog.instance.record(details.exception, details.stack, context: 'flutter');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorLog.instance.record(error, stack, context: 'async');
    return true;
  };
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const _FriendlyError();
  }

  AppServices services;
  try {
    services = await bootstrap();
  } catch (e, st) {
    ErrorLog.instance.record(e, st, context: 'startup');
    runApp(_StartupFailed(error: e));
    return;
  }
  runApp(AgroApp(services: services));

  // Ежедневная автокопия — в фоне, не задерживает запуск.
  unawaited(services.backup.autoBackupIfDue(services.farm).catchError((Object e, StackTrace st) {
    ErrorLog.instance.record(e, st, context: 'auto-backup');
    return null;
  }));
}

/// Вместо «красного экрана» в релизе — спокойное сообщение.
class _FriendlyError extends StatelessWidget {
  const _FriendlyError();

  @override
  Widget build(BuildContext context) => const Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: Color(0xFFF1F8E9),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Ин қисм кушода нашуд. Маълумоти шумо бехатар аст. '
                'Эта часть не открылась. Ваши данные в сохранности.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF33691E), fontSize: 14),
              ),
            ),
          ),
        ),
      );
}

/// Если запуск не удался (например, нет места на телефоне).
class _StartupFailed extends StatelessWidget {
  const _StartupFailed({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.eco, size: 64, color: Color(0xFF2E7D32)),
                  const SizedBox(height: 16),
                  const Text(
                    'Барнома оғоз нашуд / Приложение не запустилось',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text('$error', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  const Text(
                    'Ҷойи холиро дар телефон санҷед ва барномаро аз нав кушоед. '
                    'Проверьте свободное место и откройте приложение снова.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

Future<AppServices> bootstrap({
  LocalStore? store,
  NotificationService? notifications,
  AppConfig? config,
  PlantClassifier? classifier,
  bool loadModel = true,
}) async {
  final cfg = config ?? AppConfig.fromFlavor();
  final st = store ?? await FileStore.open();
  // Основная база — SQLite; в тестах (store передан) — JSON в памяти.
  final farm = FarmRepository(store != null ? JsonFarmStore(st) : await openFarmStore(st));
  final settings = SettingsRepository(st);
  final notif = notifications ?? LocalNotificationService();
  final results = await Future.wait([
    farm.load(),
    settings.load(),
    KnowledgeBase.load(),
    notif.init(),
  ]);

  // Своя модель: в offline — основная, в online — запасная (нет ключа или сети).
  OfflineDiagnoser? offline;
  final cls = classifier ?? (cfg.isOffline || loadModel ? await TfliteClassifier.tryLoad() : null);
  if (cls != null) offline = OfflineDiagnoser(cls, await DiseaseBase.load());

  return AppServices(
    farm: farm,
    settings: settings,
    ai: AiService(),
    notifications: notif,
    backup: BackupService(),
    knowledge: results[2] as KnowledgeBase,
    config: cfg,
    offline: offline,
    // Погода — только online и не в тестах (store передан в тестах).
    weather: (!cfg.isOffline && store == null) ? WeatherService() : null,
  );
}
