import 'package:agro_ai/models/crop_cycle.dart';
import 'package:agro_ai/models/harvest.dart';
import 'package:agro_ai/models/irrigation.dart';
import 'package:agro_ai/models/plant_scan.dart';
import 'package:agro_ai/models/plot.dart';
import 'package:agro_ai/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final d = DateTime(2026, 4, 1, 8, 30);

  test('Plot JSON roundtrip', () {
    final p = Plot(
        id: 'p1',
        name: 'Боғи калон',
        areaHa: 1.5,
        location: 'Ваҳдат',
        soilType: SoilType.clay,
        createdAt: d);
    final r = Plot.fromJson(p.toJson());
    expect(r.name, 'Боғи калон');
    expect(r.areaHa, 1.5);
    expect(r.soilType, SoilType.clay);
    expect(r.createdAt, d);
  });

  test('unknown enum falls back instead of crashing', () {
    final p = Plot.fromJson({'id': 'x', 'name': 'a', 'areaHa': '2', 'soilType': '???'});
    expect(p.soilType, SoilType.other);
    expect(p.areaHa, 2);
  });

  test('CropCycle progress and days', () {
    final c = CropCycle(
      id: 'c',
      plotId: 'p',
      cropName: 'Пахта',
      plantingDate: DateTime(2026, 4, 1),
      expectedHarvestDate: DateTime(2026, 4, 11),
    );
    expect(c.daysSincePlanting(DateTime(2026, 4, 6)), 5);
    expect(c.progress(DateTime(2026, 4, 6)), closeTo(0.5, 1e-9));
    expect(c.progress(DateTime(2026, 6, 1)), 1);
    expect(c.daysSincePlanting(DateTime(2026, 3, 1)), 0);
    final r = CropCycle.fromJson(c.toJson());
    expect(r.expectedHarvestDate, DateTime(2026, 4, 11));
    expect(r.status, CycleStatus.growing);
  });

  test('Irrigation roundtrip and stable notification id', () {
    final i = Irrigation(
      id: 'abc123',
      plotId: 'p',
      date: d,
      durationMinutes: 45,
      volumeM3: 120,
      method: IrrigationMethod.drip,
      nextPlannedDate: DateTime(2026, 4, 8),
      remind: true,
    );
    final r = Irrigation.fromJson(i.toJson());
    expect(r.method, IrrigationMethod.drip);
    expect(r.remind, isTrue);
    expect(r.volumeM3, 120);
    expect(i.notificationId, r.notificationId);
    expect(i.notificationId, isNonNegative);
    expect(i.notificationId, isNot(Irrigation.fromJson({...i.toJson(), 'id': 'abc124'}).notificationId));
  });

  test('Transaction signed amount', () {
    final t = FarmTransaction(
        id: 't',
        type: TransactionType.expense,
        category: TransactionCategory.fertilizer,
        amount: 300,
        date: d);
    expect(t.signedAmount, -300);
    expect(FarmTransaction.fromJson(t.toJson()).category,
        TransactionCategory.fertilizer);
  });

  test('Harvest total value', () {
    final h = Harvest(
        id: 'h', plotId: 'p', cropName: 'Пиёз', date: d, quantityKg: 1000, pricePerKg: 2.5);
    expect(h.totalValue, 2500);
    expect(Harvest.fromJson(h.toJson()).pricePerKg, 2.5);
  });

  test('PlantScan clamps confidence', () {
    final s = PlantScan.fromJson({
      'id': 's',
      'imagePath': '/x.jpg',
      'diagnosis': 'Фитофтороз',
      'isHealthy': false,
      'confidence': 7,
      'severity': 'high',
      'symptoms': ['доғ'],
    });
    expect(s.confidence, 1);
    expect(s.severity, Severity.high);
    expect(s.symptoms, ['доғ']);
    expect(s.recommendations, isEmpty);
  });
}
