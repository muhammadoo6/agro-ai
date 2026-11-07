import 'package:flutter/foundation.dart';

import 'farm_store.dart';
import 'local_store.dart';
import 'sqlite_farm_store.dart';

/// Открывает основную базу (SQLite). При первом запуске после обновления
/// переносит данные из старого JSON-файла. Если SQLite недоступна —
/// приложение продолжает работать на JSON (данные не теряются).
Future<FarmStore> openFarmStore(LocalStore legacy) async {
  try {
    final sql = await SqliteFarmStore.open();
    await _migrateLegacy(legacy, sql);
    return sql;
  } catch (e) {
    debugPrint('SQLite unavailable, falling back to JSON: $e');
    return JsonFarmStore(legacy);
  }
}

Future<void> _migrateLegacy(LocalStore legacy, SqliteFarmStore sql) async {
  final raw = await legacy.read('farm');
  if (raw == null || raw.isEmpty) return;
  final old = await JsonFarmStore(legacy).loadAll();
  final hasOld = old.values.any((l) => l.isNotEmpty);
  final current = await sql.loadAll();
  final sqlEmpty = current.values.every((l) => l.isEmpty);
  if (hasOld && sqlEmpty) {
    await sql.replaceAll(old);
    debugPrint('Migrated ${old.values.fold<int>(0, (s, l) => s + l.length)} records to SQLite');
  }
  // Старый файл сохраняем под другим именем — на всякий случай.
  await legacy.write('farm_legacy_migrated', raw);
  await legacy.delete('farm');
}
