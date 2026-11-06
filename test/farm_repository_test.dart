import 'dart:convert';

import 'package:agro_ai/data/local/local_store.dart';
import 'package:agro_ai/data/repositories/farm_repository.dart';
import 'package:agro_ai/data/repositories/settings_repository.dart';
import 'package:agro_ai/models/crop_cycle.dart';
import 'package:agro_ai/models/harvest.dart';
import 'package:agro_ai/models/irrigation.dart';
import 'package:agro_ai/models/plant_scan.dart';
import 'package:agro_ai/models/plot.dart';
import 'package:agro_ai/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

Plot plot(String id, {double area = 1}) =>
    Plot(id: id, name: 'Қитъа $id', areaHa: area, createdAt: DateTime(2026, 1, 1));

FarmTransaction tx(String id, TransactionType type, double amount, DateTime date,
        {String? plotId, TransactionCategory cat = TransactionCategory.other}) =>
    FarmTransaction(
        id: id, type: type, category: cat, amount: amount, date: date, plotId: plotId);

void main() {
  late MemoryStore store;
  late FarmRepository repo;

  setUp(() async {
    store = MemoryStore();
    repo = FarmRepository(store);
    await repo.load();
  });

  test('data survives reload', () async {
    await repo.savePlot(plot('a', area: 2));
    await repo.savePlot(plot('b', area: 0.5));
    await repo.saveCycle(CropCycle(
        id: 'c', plotId: 'a', cropName: 'Гандум', plantingDate: DateTime(2026, 10, 1)));
    await repo.flush();

    final again = FarmRepository(store);
    await again.load();
    expect(again.plots.length, 2);
    expect(again.totalAreaHa, 2.5);
    expect(again.activeCycleForPlot('a')?.cropName, 'Гандум');
  });

  test('savePlot updates existing instead of duplicating', () async {
    await repo.savePlot(plot('a'));
    await repo.savePlot(plot('a').copyWith(name: 'Нав'));
    expect(repo.plots.length, 1);
    expect(repo.plots.single.name, 'Нав');
  });

  test('deletePlot cascades and detaches transactions', () async {
    await repo.savePlot(plot('a'));
    await repo.saveCycle(CropCycle(
        id: 'c', plotId: 'a', cropName: 'X', plantingDate: DateTime(2026, 4, 1)));
    await repo.saveIrrigation(Irrigation(
        id: 'i', plotId: 'a', date: DateTime(2026, 4, 2), durationMinutes: 30));
    await repo.saveHarvest(Harvest(
        id: 'h', plotId: 'a', cropName: 'X', date: DateTime(2026, 8, 1), quantityKg: 10));
    await repo.saveTransaction(
        tx('t', TransactionType.expense, 100, DateTime(2026, 4, 1), plotId: 'a'));
    await repo.saveScan(PlantScan(
        id: 's',
        imagePath: '/x',
        date: DateTime(2026, 5, 1),
        plotId: 'a',
        diagnosis: 'd',
        isHealthy: true));

    final removed = await repo.deletePlot('a');
    expect(removed.map((e) => e.id), ['i']);
    expect(repo.plots, isEmpty);
    expect(repo.cycles, isEmpty);
    expect(repo.irrigations, isEmpty);
    expect(repo.harvests, isEmpty);
    expect(repo.transactions.single.plotId, isNull);
    expect(repo.transactions.single.amount, 100);
    expect(repo.scans.single.plotId, isNull);
  });

  test('summary by period, plot and category', () async {
    await repo.saveTransaction(tx('1', TransactionType.income, 1000, DateTime(2026, 5, 10), plotId: 'a'));
    await repo.saveTransaction(tx('2', TransactionType.expense, 300, DateTime(2026, 5, 31, 23),
        plotId: 'a', cat: TransactionCategory.seeds));
    await repo.saveTransaction(tx('3', TransactionType.expense, 200, DateTime(2026, 4, 1),
        plotId: 'b', cat: TransactionCategory.seeds));
    await repo.saveTransaction(tx('4', TransactionType.expense, 50, DateTime(2026, 5, 2),
        cat: TransactionCategory.fuel));

    final all = repo.summary();
    expect(all.income, 1000);
    expect(all.expense, 550);
    expect(all.balance, 450);
    expect(all.expenseByCategory[TransactionCategory.seeds], 500);

    final may = repo.summary(from: DateTime(2026, 5, 1), to: DateTime(2026, 5, 31));
    expect(may.expense, 350); // 31 май 23:00 ҳам дохил мешавад
    expect(repo.summary(plotId: 'a').balance, 700);
  });

  test('harvest as income creates, updates and removes linked transaction', () async {
    final h = Harvest(
        id: 'h1', plotId: 'a', cropName: 'Пиёз', date: DateTime(2026, 8, 1),
        quantityKg: 1000, pricePerKg: 2);
    await repo.saveHarvest(h, asIncome: true);
    expect(repo.transactions.single.amount, 2000);
    expect(repo.transactions.single.harvestId, 'h1');
    expect(repo.harvestHasIncome('h1'), isTrue);

    await repo.saveHarvest(
        Harvest(id: 'h1', plotId: 'a', cropName: 'Пиёз', date: h.date, quantityKg: 1500, pricePerKg: 2),
        asIncome: true);
    expect(repo.transactions.length, 1);
    expect(repo.transactions.single.amount, 3000);

    await repo.saveHarvest(h, asIncome: false);
    expect(repo.transactions, isEmpty);

    await repo.saveHarvest(h, asIncome: true);
    await repo.deleteHarvest('h1');
    expect(repo.transactions, isEmpty);
  });

  test('upcoming irrigations use only the latest record per plot', () async {
    await repo.savePlot(plot('a'));
    await repo.savePlot(plot('b'));
    await repo.saveIrrigation(Irrigation(
        id: 'old', plotId: 'a', date: DateTime(2026, 4, 1), durationMinutes: 30,
        nextPlannedDate: DateTime(2026, 4, 5)));
    await repo.saveIrrigation(Irrigation(
        id: 'new', plotId: 'a', date: DateTime(2026, 4, 5), durationMinutes: 30,
        nextPlannedDate: DateTime(2026, 4, 12)));
    await repo.saveIrrigation(Irrigation(
        id: 'b1', plotId: 'b', date: DateTime(2026, 4, 3), durationMinutes: 30,
        nextPlannedDate: DateTime(2026, 4, 9)));
    expect(repo.upcomingIrrigations().map((e) => e.id), ['b1', 'new']);
  });

  test('corrupted storage does not crash, bad records are skipped', () async {
    final s = MemoryStore()
      ..data[FarmRepository.storageKey] = jsonEncode({
        'plots': [
          {'id': 'ok', 'name': 'A', 'areaHa': 1},
          {'name': 'no id'},
          'garbage',
        ],
      });
    final r = FarmRepository(s);
    await r.load();
    expect(r.plots.map((e) => e.id), ['ok']);

    final broken = MemoryStore()..data[FarmRepository.storageKey] = '{not json';
    final r2 = FarmRepository(broken);
    await r2.load();
    expect(r2.isLoaded, isTrue);
    expect(r2.plots, isEmpty);
  });

  test('settings persist separately and keep api key out of farm data', () async {
    final settings = SettingsRepository(store);
    await settings.update(const AppSettings(languageCode: 'ru', apiKey: 'sk-ant-secret'));
    final again = SettingsRepository(store);
    await again.load();
    expect(again.value.languageCode, 'ru');
    expect(again.value.hasApiKey, isTrue);
    await repo.savePlot(plot('a'));
    await repo.flush();
    expect(store.data[FarmRepository.storageKey], isNot(contains('sk-ant')));
  });
}
