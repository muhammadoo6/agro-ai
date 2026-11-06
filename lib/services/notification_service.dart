import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Ёдраскунии обёрӣ.
abstract class NotificationService {
  Future<void> init();
  Future<bool> requestPermission();

  /// Огоҳинома дар соати [hour] субҳи рӯзи [date].
  Future<void> scheduleIrrigation({
    required int id,
    required DateTime date,
    required String title,
    required String body,
    int hour = 7,
  });
  Future<void> cancel(int id);
  Future<void> cancelAll();
}

/// Барои санҷишҳо ва платформаҳое, ки огоҳинома надоранд.
class NoopNotificationService implements NotificationService {
  final scheduled = <int, DateTime>{};

  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> scheduleIrrigation({
    required int id,
    required DateTime date,
    required String title,
    required String body,
    int hour = 7,
  }) async =>
      scheduled[id] = DateTime(date.year, date.month, date.day, hour);
  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
  @override
  Future<void> cancelAll() async => scheduled.clear();
}

class LocalNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'irrigation';
  static const _channelName = 'Обёрӣ';

  /// Тоҷикистон як минтақаи вақт дорад (UTC+5, бе вақти тобистона).
  static const _zone = 'Asia/Dushanbe';

  @override
  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(_zone));
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings: settings);
      _ready = true;
    } catch (e) {
      debugPrint('Notifications init failed: $e');
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return false;
  }

  @override
  Future<void> scheduleIrrigation({
    required int id,
    required DateTime date,
    required String title,
    required String body,
    int hour = 7,
  }) async {
    if (!_ready) return;
    var when = tz.TZDateTime(tz.local, date.year, date.month, date.day, hour);
    final now = tz.TZDateTime.now(tz.local);
    if (!when.isAfter(now)) {
      // Агар вақт гузашта бошад, баъд аз 1 дақиқа хабар медиҳем.
      if (now.difference(when).inDays >= 1) return;
      when = now.add(const Duration(minutes: 1));
    }
    await requestPermission();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (_ready) await _plugin.cancel(id: id);
  }

  @override
  Future<void> cancelAll() async {
    if (_ready) await _plugin.cancelAll();
  }
}
