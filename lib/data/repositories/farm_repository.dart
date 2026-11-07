import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/utils/formatters.dart';
import '../../models/crop_cycle.dart';
import '../../models/harvest.dart';
import '../../models/irrigation.dart';
import '../../models/plant_scan.dart';
import '../../models/plot.dart';
import '../../models/transaction.dart';
import '../local/farm_store.dart';

/// Хулосаи молиявӣ барои давра.
class FinanceSummary {
  const FinanceSummary({
    required this.income,
    required this.expense,
    required this.expenseByCategory,
  });

  final double income;
  final double expense;
  final Map<TransactionCategory, double> expenseByCategory;

  double get balance => income - expense;
}

/// Хондан ва сабти ҳамаи маълумоти хоҷагӣ.
///
/// Маълумот дар хотира нигоҳ дошта мешавад ва баъд аз ҳар тағйирот
/// ба [LocalStore] сабт мегардад.
class FarmRepository extends ChangeNotifier {
  FarmRepository(this._store);

  static const schemaVersion = 1;

  final FarmStore _store;

  /// Что сейчас лежит в базе: table → (id → JSON-строка). Нужно, чтобы
  /// записывать только изменённые записи.
  final Map<String, Map<String, String>> _persisted = {
    for (final t in farmTables) t: <String, String>{},
  };

  /// Последняя ошибка записи (показывается в «О данных»).
  Object? lastSaveError;

  String get storageDescription => _store.description;

  final List<Plot> _plots = [];
  final List<CropCycle> _cycles = [];
  final List<Irrigation> _irrigations = [];
  final List<FarmTransaction> _transactions = [];
  final List<Harvest> _harvests = [];
  final List<PlantScan> _scans = [];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void>? _pendingSave;

  List<Plot> get plots => List.unmodifiable(_plots);
  List<CropCycle> get cycles => List.unmodifiable(_cycles);
  List<Irrigation> get irrigations => List.unmodifiable(_irrigations);
  List<FarmTransaction> get transactions => List.unmodifiable(_transactions);
  List<Harvest> get harvests => List.unmodifiable(_harvests);
  List<PlantScan> get scans => List.unmodifiable(_scans);

  // ---------- бор кардан / сабт ----------

  Future<void> load() async {
    try {
      final data = await _store.loadAll();
      _applyJson(data);
      _snapshotPersisted();
    } catch (e) {
      debugPrint('FarmRepository: load failed: $e');
      lastSaveError = e;
    }
    _loaded = true;
    notifyListeners();
  }

  Map<String, List<Map<String, dynamic>>> _tablesJson() => {
        'plots': _plots.map((e) => e.toJson()).toList(),
        'cycles': _cycles.map((e) => e.toJson()).toList(),
        'irrigations': _irrigations.map((e) => e.toJson()).toList(),
        'transactions': _transactions.map((e) => e.toJson()).toList(),
        'harvests': _harvests.map((e) => e.toJson()).toList(),
        'scans': _scans.map((e) => e.toJson()).toList(),
      };

  void _snapshotPersisted() {
    final t = _tablesJson();
    for (final table in farmTables) {
      _persisted[table] = {
        for (final row in t[table]!) row['id'] as String: jsonEncode(row),
      };
    }
  }

  int get totalRecords => farmTables.fold(0, (s, t) => s + _persisted[t]!.length);

  Map<String, dynamic> toJson() => {
        'schema': schemaVersion,
        'plots': _plots.map((e) => e.toJson()).toList(),
        'cycles': _cycles.map((e) => e.toJson()).toList(),
        'irrigations': _irrigations.map((e) => e.toJson()).toList(),
        'transactions': _transactions.map((e) => e.toJson()).toList(),
        'harvests': _harvests.map((e) => e.toJson()).toList(),
        'scans': _scans.map((e) => e.toJson()).toList(),
      };

  void _applyJson(Map<String, dynamic> j) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) f) {
      final list = j[key];
      if (list is! List) return [];
      final out = <T>[];
      for (final e in list) {
        try {
          out.add(f(Map<String, dynamic>.from(e as Map)));
        } catch (err) {
          debugPrint('FarmRepository: сабти нодуруст дар $key: $err');
        }
      }
      return out;
    }

    _plots
      ..clear()
      ..addAll(parse('plots', Plot.fromJson));
    _cycles
      ..clear()
      ..addAll(parse('cycles', CropCycle.fromJson));
    _irrigations
      ..clear()
      ..addAll(parse('irrigations', Irrigation.fromJson));
    _transactions
      ..clear()
      ..addAll(parse('transactions', FarmTransaction.fromJson));
    _harvests
      ..clear()
      ..addAll(parse('harvests', Harvest.fromJson));
    _scans
      ..clear()
      ..addAll(parse('scans', PlantScan.fromJson));
  }

  /// Иваз кардани ҳамаи маълумот (барқароркунӣ аз нусха) — як транзаксия.
  Future<void> replaceAll(Map<String, dynamic> json) {
    _applyJson(json);
    notifyListeners();
    final data = _tablesJson();
    return _enqueue(() async {
      await _store.replaceAll(data);
      _snapshotPersisted();
    });
  }

  Future<void> clearAll() => replaceAll(const {});

  /// Ҳисоби тағйирот ва сабти онҳо дар як транзаксия. Сабтҳо пай дар пай.
  Future<void> _commit() {
    notifyListeners();
    final changes = FarmChanges();
    final now = _tablesJson();
    final newPersisted = <String, Map<String, String>>{};
    for (final t in farmTables) {
      final old = _persisted[t]!;
      final cur = <String, String>{};
      for (final row in now[t]!) {
        final id = row['id'] as String;
        final enc = jsonEncode(row);
        cur[id] = enc;
        if (old[id] != enc) (changes.upserts[t] ??= {})[id] = row;
      }
      for (final id in old.keys) {
        if (!cur.containsKey(id)) (changes.deletes[t] ??= {}).add(id);
      }
      newPersisted[t] = cur;
    }
    _persisted
      ..clear()
      ..addAll(newPersisted);
    if (changes.isEmpty) return _pendingSave ?? Future.value();
    return _enqueue(() => _store.apply(changes));
  }

  Future<void> _enqueue(Future<void> Function() op) {
    final prev = _pendingSave;
    final next = (prev == null ? op() : prev.catchError((Object _) {}).then((_) => op()))
        .then((_) => lastSaveError = null, onError: (Object e) {
      lastSaveError = e;
      debugPrint('FarmRepository: save failed: $e');
      throw e;
    });
    _pendingSave = next;
    return next;
  }

  void _upsert<T>(List<T> list, T item, String Function(T) id) {
    final i = list.indexWhere((e) => id(e) == id(item));
    if (i >= 0) {
      list[i] = item;
    } else {
      list.add(item);
    }
  }

  // ---------- қитъаҳо ----------

  Plot? plotById(String? id) {
    if (id == null) return null;
    for (final p in _plots) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> savePlot(Plot p) {
    _upsert(_plots, p, (e) => e.id);
    return _commit();
  }

  /// Нест кардани қитъа бо ҳамаи сабтҳои вобаста.
  Future<List<Irrigation>> deletePlot(String id) {
    final removedIrrigations =
        _irrigations.where((e) => e.plotId == id).toList();
    _plots.removeWhere((e) => e.id == id);
    _cycles.removeWhere((e) => e.plotId == id);
    _irrigations.removeWhere((e) => e.plotId == id);
    _harvests.removeWhere((e) => e.plotId == id);
    // Сабтҳои молиявӣ мемонанд, вале аз қитъа ҷудо мешаванд.
    for (var i = 0; i < _transactions.length; i++) {
      final t = _transactions[i];
      if (t.plotId == id) {
        _transactions[i] = FarmTransaction(
          id: t.id,
          type: t.type,
          category: t.category,
          amount: t.amount,
          date: t.date,
          harvestId: t.harvestId,
          note: t.note,
        );
      }
    }
    for (var i = 0; i < _scans.length; i++) {
      final s = _scans[i];
      if (s.plotId == id) {
        _scans[i] = PlantScan.fromJson({...s.toJson(), 'plotId': null});
      }
    }
    return _commit().then((_) => removedIrrigations);
  }

  double get totalAreaHa => _plots.fold(0, (s, p) => s + p.areaHa);

  // ---------- мавсимҳо ----------

  List<CropCycle> cyclesForPlot(String plotId) =>
      _cycles.where((c) => c.plotId == plotId).toList()
        ..sort((a, b) => b.plantingDate.compareTo(a.plantingDate));

  List<CropCycle> get activeCycles =>
      _cycles.where((c) => c.isActive).toList();

  CropCycle? activeCycleForPlot(String plotId) {
    final list = cyclesForPlot(plotId).where((c) => c.isActive);
    return list.isEmpty ? null : list.first;
  }

  Future<void> saveCycle(CropCycle c) {
    _upsert(_cycles, c, (e) => e.id);
    return _commit();
  }

  Future<void> deleteCycle(String id) {
    _cycles.removeWhere((e) => e.id == id);
    return _commit();
  }

  // ---------- обёрӣ ----------

  List<Irrigation> irrigationsForPlot(String plotId) =>
      _irrigations.where((e) => e.plotId == plotId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<Irrigation> get irrigationsSorted =>
      [..._irrigations]..sort((a, b) => b.date.compareTo(a.date));

  /// Обёриҳои навбатӣ: барои ҳар қитъа танҳо сабти охирин ба ҳисоб меравад.
  List<Irrigation> upcomingIrrigations({DateTime? now}) {
    final latest = <String, Irrigation>{};
    for (final e in _irrigations) {
      final cur = latest[e.plotId];
      if (cur == null || e.date.isAfter(cur.date)) latest[e.plotId] = e;
    }
    final list = latest.values
        .where((e) => e.nextPlannedDate != null && plotById(e.plotId) != null)
        .toList()
      ..sort((a, b) => a.nextPlannedDate!.compareTo(b.nextPlannedDate!));
    return list;
  }

  Future<void> saveIrrigation(Irrigation i) {
    _upsert(_irrigations, i, (e) => e.id);
    return _commit();
  }

  Future<void> deleteIrrigation(String id) {
    _irrigations.removeWhere((e) => e.id == id);
    return _commit();
  }

  double totalWaterM3({String? plotId}) => _irrigations
      .where((e) => plotId == null || e.plotId == plotId)
      .fold(0, (s, e) => s + (e.volumeM3 ?? 0));

  // ---------- молия ----------

  List<FarmTransaction> get transactionsSorted =>
      [..._transactions]..sort((a, b) => b.date.compareTo(a.date));

  Future<void> saveTransaction(FarmTransaction t) {
    _upsert(_transactions, t, (e) => e.id);
    return _commit();
  }

  Future<void> deleteTransaction(String id) {
    _transactions.removeWhere((e) => e.id == id);
    return _commit();
  }

  FinanceSummary summary({DateTime? from, DateTime? to, String? plotId}) {
    double inc = 0, exp = 0;
    final byCat = <TransactionCategory, double>{};
    for (final t in _transactions) {
      if (from != null && t.date.isBefore(dateOnly(from))) continue;
      if (to != null && !t.date.isBefore(dateOnly(to).add(const Duration(days: 1)))) {
        continue;
      }
      if (plotId != null && t.plotId != plotId) continue;
      if (t.type == TransactionType.income) {
        inc += t.amount;
      } else {
        exp += t.amount;
        byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
      }
    }
    return FinanceSummary(income: inc, expense: exp, expenseByCategory: byCat);
  }

  /// Даромад/хароҷот барои [months] моҳи охир (аз кӯҳна ба нав).
  List<({DateTime month, double income, double expense})> monthlyTotals(
      {int months = 6, DateTime? now}) {
    final t = now ?? DateTime.now();
    final out = <({DateTime month, double income, double expense})>[];
    for (var k = months - 1; k >= 0; k--) {
      final m = DateTime(t.year, t.month - k, 1);
      final next = DateTime(m.year, m.month + 1, 1);
      double inc = 0, exp = 0;
      for (final x in _transactions) {
        if (x.date.isBefore(m) || !x.date.isBefore(next)) continue;
        if (x.type == TransactionType.income) {
          inc += x.amount;
        } else {
          exp += x.amount;
        }
      }
      out.add((month: m, income: inc, expense: exp));
    }
    return out;
  }

  // ---------- ҳосил ----------

  List<Harvest> get harvestsSorted =>
      [..._harvests]..sort((a, b) => b.date.compareTo(a.date));

  List<Harvest> harvestsForPlot(String plotId) =>
      _harvests.where((h) => h.plotId == plotId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// Сабти ҳосил; агар [asIncome] бошад, даромади мувофиқ низ сохта/навсозӣ мешавад.
  Future<void> saveHarvest(Harvest h, {bool asIncome = false, String? incomeId}) {
    _upsert(_harvests, h, (e) => e.id);
    final linked = _transactions.where((t) => t.harvestId == h.id).toList();
    if (asIncome && h.totalValue > 0) {
      final t = FarmTransaction(
        id: linked.isNotEmpty ? linked.first.id : (incomeId ?? '${h.id}_inc'),
        type: TransactionType.income,
        category: TransactionCategory.sale,
        amount: h.totalValue,
        date: h.date,
        plotId: h.plotId,
        harvestId: h.id,
        note: '${h.cropName} ${formatNumber(h.quantityKg)} кг',
      );
      _upsert(_transactions, t, (e) => e.id);
    } else {
      _transactions.removeWhere((t) => t.harvestId == h.id);
    }
    return _commit();
  }

  bool harvestHasIncome(String harvestId) =>
      _transactions.any((t) => t.harvestId == harvestId);

  Future<void> deleteHarvest(String id) {
    _harvests.removeWhere((e) => e.id == id);
    _transactions.removeWhere((t) => t.harvestId == id);
    return _commit();
  }

  double totalHarvestKg({String? plotId}) => _harvests
      .where((h) => plotId == null || h.plotId == plotId)
      .fold(0, (s, h) => s + h.quantityKg);

  // ---------- сканҳо ----------

  List<PlantScan> get scansSorted =>
      [..._scans]..sort((a, b) => b.date.compareTo(a.date));

  Future<void> saveScan(PlantScan s) {
    _upsert(_scans, s, (e) => e.id);
    return _commit();
  }

  Future<void> deleteScan(String id) {
    _scans.removeWhere((e) => e.id == id);
    return _commit();
  }

  /// Барои санҷишҳо: интизори анҷоми сабт.
  @visibleForTesting
  Future<void> flush() => _pendingSave ?? Future.value();
}
