import 'dart:io';

import 'package:agro_ai/data/local/farm_store.dart';
import 'package:agro_ai/data/local/sqlite_farm_store.dart';
import 'package:agro_ai/data/repositories/farm_repository.dart';
import 'package:agro_ai/models/harvest.dart';
import 'package:agro_ai/models/irrigation.dart';
import 'package:agro_ai/models/plot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  Plot plot(String id) =>
      Plot(id: id, name: 'Қитъа $id', areaHa: 1.5, createdAt: DateTime(2026, 3, 1));

  test('repository on SQLite persists, updates and cascades across reopen', () async {
    final dir = Directory.systemTemp.createTempSync('agro_db_');
    addTearDown(() => dir.deleteSync(recursive: true));

    var store = await SqliteFarmStore.open(directory: dir.path, factory: factory);
    var repo = FarmRepository(store);
    await repo.load();
    await repo.savePlot(plot('a'));
    await repo.savePlot(plot('b'));
    await repo.saveIrrigation(Irrigation(
        id: 'i1', plotId: 'a', date: DateTime(2026, 4, 1), durationMinutes: 40));
    await repo.saveHarvest(
        Harvest(id: 'h1', plotId: 'a', cropName: 'Пахта', date: DateTime(2026, 9, 1),
            quantityKg: 3000, pricePerKg: 6),
        asIncome: true);
    await repo.savePlot(plot('b').copyWith(name: 'Нав'));
    await repo.flush();
    expect(await store.integrityOk(), isTrue);
    expect(await store.count('plots'), 2);
    expect(await store.count('transactions'), 1);
    await store.close();

    // Повторное открытие — данные на месте.
    store = await SqliteFarmStore.open(directory: dir.path, factory: factory);
    repo = FarmRepository(store);
    await repo.load();
    expect(repo.plots.map((p) => p.name).toSet(), {'Қитъа a', 'Нав'});
    expect(repo.summary().income, 18000);

    await repo.deletePlot('a');
    await repo.flush();
    expect(await store.count('plots'), 1);
    expect(await store.count('irrigations'), 0);
    expect(await store.count('harvests'), 0);
    await store.close();
  });

  test('replaceAll is atomic and clears old rows', () async {
    final store = await SqliteFarmStore.open(directory: inMemoryDatabasePath, factory: factory);
    await store.apply(FarmChanges()..upserts['plots'] = {'x': plot('x').toJson()});
    await store.replaceAll({
      'plots': [plot('y').toJson()],
    });
    final all = await store.loadAll();
    expect(all['plots']!.map((e) => e['id']), ['y']);
    await store.close();
  });

  test('many records: only changed rows are written', () async {
    final store = await SqliteFarmStore.open(directory: inMemoryDatabasePath, factory: factory);
    final repo = FarmRepository(store);
    await repo.load();
    for (var i = 0; i < 500; i++) {
      await repo.savePlot(plot('p$i'));
    }
    await repo.flush();
    expect(await store.count('plots'), 500);
    expect(repo.totalRecords, 500);
    await store.close();
  });
}
