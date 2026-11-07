import 'dart:convert';

import 'local_store.dart';

/// Таблицы базы данных хозяйства.
const farmTables = ['plots', 'cycles', 'irrigations', 'transactions', 'harvests', 'scans'];

/// Изменения для одной записи в базу: что добавить/обновить и что удалить.
class FarmChanges {
  FarmChanges();

  /// table → (id → JSON записи)
  final Map<String, Map<String, Map<String, dynamic>>> upserts = {};

  /// table → ids
  final Map<String, Set<String>> deletes = {};

  bool get isEmpty =>
      upserts.values.every((m) => m.isEmpty) && deletes.values.every((s) => s.isEmpty);
}

/// Хранилище данных хозяйства.
///
/// Основная реализация — [SqliteFarmStore] (SQLite, транзакции, индексы).
/// [JsonFarmStore] — запасной вариант и для тестов.
abstract class FarmStore {
  /// Все записи: table → список JSON.
  Future<Map<String, List<Map<String, dynamic>>>> loadAll();

  /// Применить изменения атомарно (всё или ничего).
  Future<void> apply(FarmChanges changes);

  /// Заменить все данные (восстановление из копии) атомарно.
  Future<void> replaceAll(Map<String, List<Map<String, dynamic>>> data);

  /// Где лежат данные (для экрана «О данных»).
  String get description;

  Future<void> close() async {}
}

/// Хранение одним JSON-документом в [LocalStore] (атомарная запись файла).
class JsonFarmStore implements FarmStore {
  JsonFarmStore(this._store, {this.key = 'farm'});

  final LocalStore _store;
  final String key;
  Map<String, List<Map<String, dynamic>>>? _cache;

  @override
  String get description => 'JSON ($key)';

  @override
  Future<Map<String, List<Map<String, dynamic>>>> loadAll() async {
    final raw = await _store.read(key);
    final out = {for (final t in farmTables) t: <Map<String, dynamic>>[]};
    if (raw != null && raw.isNotEmpty) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        for (final t in farmTables) {
          final list = j[t];
          if (list is List) {
            for (final e in list) {
              if (e is Map) out[t]!.add(Map<String, dynamic>.from(e));
            }
          }
        }
      } catch (_) {
        // повреждённый файл — начинаем с пустых данных (копии есть в автобэкапах)
      }
    }
    _cache = out;
    return {for (final e in out.entries) e.key: List.of(e.value)};
  }

  @override
  Future<void> apply(FarmChanges changes) async {
    final data = _cache ?? await loadAll();
    for (final t in farmTables) {
      final ups = changes.upserts[t] ?? const {};
      final dels = changes.deletes[t] ?? const <String>{};
      final list = data[t]!..removeWhere((e) => dels.contains(e['id']) || ups.containsKey(e['id']));
      list.addAll(ups.values);
    }
    await _write(data);
  }

  @override
  Future<void> replaceAll(Map<String, List<Map<String, dynamic>>> data) async {
    _cache = {for (final t in farmTables) t: List.of(data[t] ?? const [])};
    await _write(_cache!);
  }

  Future<void> _write(Map<String, List<Map<String, dynamic>>> data) =>
      _store.write(key, jsonEncode({'schema': 1, ...data}));

  @override
  Future<void> close() async {}
}
