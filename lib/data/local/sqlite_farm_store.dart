import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'farm_store.dart';

/// База данных SQLite на телефоне.
///
/// * Каждая сущность — своя таблица: id (PK), plot_id, date (индексы), data (JSON).
/// * Все изменения — в транзакции: при сбое питания база не повреждается.
/// * Версия схемы и миграции — через `onUpgrade`.
class SqliteFarmStore implements FarmStore {
  SqliteFarmStore._(this._db, this.path);

  static const fileName = 'agro_ai.db';
  static const schemaVersion = 1;

  final Database _db;
  final String path;

  @override
  String get description => 'SQLite: $path';

  /// [factory] — для тестов (sqflite_common_ffi), иначе стандартный sqflite.
  static Future<SqliteFarmStore> open({String? directory, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final dir = directory ?? await f.getDatabasesPath();
    final path = directory == inMemoryDatabasePath ? inMemoryDatabasePath : p.join(dir, fileName);
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          // WAL — быстрее и надёжнее при частых записях.
          if (path != inMemoryDatabasePath) {
            await db.rawQuery('PRAGMA journal_mode=WAL');
          }
          await db.execute('PRAGMA foreign_keys=ON');
        },
        onCreate: (db, version) async {
          final batch = db.batch();
          for (final t in farmTables) {
            batch.execute('''
              CREATE TABLE $t (
                id TEXT PRIMARY KEY NOT NULL,
                plot_id TEXT,
                date TEXT,
                data TEXT NOT NULL,
                updated_at INTEGER NOT NULL
              )''');
            batch.execute('CREATE INDEX idx_${t}_plot ON $t(plot_id)');
            batch.execute('CREATE INDEX idx_${t}_date ON $t(date)');
          }
          batch.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)');
          await batch.commit(noResult: true);
        },
        onUpgrade: (db, from, to) async {
          // Миграции будущих версий схемы добавляются здесь: if (from < 2) {...}
        },
      ),
    );
    return SqliteFarmStore._(db, path);
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>> loadAll() async {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final t in farmTables) {
      final rows = await _db.query(t, columns: ['data']);
      out[t] = [
        for (final r in rows)
          if (_decode(r['data']) case final m?) m,
      ];
    }
    return out;
  }

  Map<String, dynamic>? _decode(Object? v) {
    if (v is! String) return null;
    try {
      final j = jsonDecode(v);
      return j is Map ? Map<String, dynamic>.from(j) : null;
    } catch (_) {
      return null;
    }
  }

  void _put(Batch b, String table, Map<String, dynamic> row, int now) {
    final date = row['date'] ?? row['plantingDate'] ?? row['createdAt'];
    b.insert(
      table,
      {
        'id': row['id'],
        'plot_id': row['plotId'],
        'date': date is String ? date : null,
        'data': jsonEncode(row),
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> apply(FarmChanges changes) async {
    if (changes.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      final b = txn.batch();
      for (final e in changes.deletes.entries) {
        for (final id in e.value) {
          b.delete(e.key, where: 'id = ?', whereArgs: [id]);
        }
      }
      for (final e in changes.upserts.entries) {
        for (final row in e.value.values) {
          _put(b, e.key, row, now);
        }
      }
      await b.commit(noResult: true);
    });
  }

  @override
  Future<void> replaceAll(Map<String, List<Map<String, dynamic>>> data) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      final b = txn.batch();
      for (final t in farmTables) {
        b.delete(t);
        for (final row in data[t] ?? const <Map<String, dynamic>>[]) {
          if (row['id'] is String) _put(b, t, row, now);
        }
      }
      await b.commit(noResult: true);
    });
  }

  /// Проверка целостности файла базы (для экрана «О данных»).
  Future<bool> integrityOk() async {
    final r = await _db.rawQuery('PRAGMA integrity_check');
    return r.isNotEmpty && r.first.values.first == 'ok';
  }

  Future<int> count(String table) async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM $table')) ?? 0;

  @override
  Future<void> close() => _db.close();
}
