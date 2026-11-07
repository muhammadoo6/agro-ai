import '../models/crop_cycle.dart';
import '../models/harvest.dart';
import '../models/irrigation.dart';
import '../models/plot.dart';
import '../models/transaction.dart';

/// Намунаи хоҷагӣ барои намоиш (фестивал, презентатсия).
/// Санаҳо нисбат ба [now] сохта мешаванд, то графикҳо ҳамеша «зинда» бошанд.
Map<String, dynamic> buildDemoFarm({DateTime? now}) {
  final t = now ?? DateTime.now();
  DateTime d(int daysAgo) => DateTime(t.year, t.month, t.day).subtract(Duration(days: daysAgo));
  var n = 0;
  String id(String p) => 'demo_${p}_${n++}';

  final plots = [
    Plot(id: 'demo_p1', name: 'Пахтазор — Вахш', areaHa: 5, location: 'н. Вахш, Хатлон',
        soilType: SoilType.loam, createdAt: d(200)),
    Plot(id: 'demo_p2', name: 'Гандумзор — Ҳисор', areaHa: 3, location: 'ш. Ҳисор',
        soilType: SoilType.clay, createdAt: d(200)),
    Plot(id: 'demo_p3', name: 'Картошка — Варзоб', areaHa: 1.2, location: 'н. Варзоб',
        soilType: SoilType.sand, createdAt: d(150)),
    Plot(id: 'demo_p4', name: 'Помидор — гармхона', areaHa: 0.4, location: 'Душанбе',
        soilType: SoilType.loam, createdAt: d(120)),
  ];

  final cycles = [
    CropCycle(id: id('c'), plotId: 'demo_p1', cropName: 'Пахта', variety: 'Ҳисор-31',
        plantingDate: d(110), expectedHarvestDate: d(110).add(const Duration(days: 150))),
    CropCycle(id: id('c'), plotId: 'demo_p2', cropName: 'Гандум', variety: 'Сомон',
        plantingDate: d(30), expectedHarvestDate: d(30).add(const Duration(days: 240))),
    CropCycle(id: id('c'), plotId: 'demo_p3', cropName: 'Картошка', variety: 'Пикассо',
        plantingDate: d(140), expectedHarvestDate: d(40), status: CycleStatus.harvested),
    CropCycle(id: id('c'), plotId: 'demo_p4', cropName: 'Помидор', variety: 'Пинк',
        plantingDate: d(70), expectedHarvestDate: d(70).add(const Duration(days: 120))),
  ];

  final irrigations = <Irrigation>[];
  for (final (plot, every, minutes, vol, method) in [
    ('demo_p1', 12, 180, 900.0, IrrigationMethod.furrow),
    ('demo_p2', 20, 150, 600.0, IrrigationMethod.furrow),
    ('demo_p4', 3, 40, 12.0, IrrigationMethod.drip),
  ]) {
    for (var k = 6; k >= 0; k--) {
      final date = d(k * every + 1);
      irrigations.add(Irrigation(
        id: id('i'),
        plotId: plot,
        date: date,
        durationMinutes: minutes,
        volumeM3: vol,
        method: method,
        nextPlannedDate: k == 0 ? date.add(Duration(days: every)) : null,
        remind: false,
      ));
    }
  }

  final harvests = [
    Harvest(id: 'demo_h1', plotId: 'demo_p3', cropName: 'Картошка', date: d(40),
        quantityKg: 26000, pricePerKg: 3.2, quality: HarvestQuality.high),
    Harvest(id: 'demo_h2', plotId: 'demo_p4', cropName: 'Помидор', date: d(10),
        quantityKg: 4200, pricePerKg: 6.5),
    Harvest(id: 'demo_h3', plotId: 'demo_p4', cropName: 'Помидор', date: d(3),
        quantityKg: 3100, pricePerKg: 7),
  ];

  final tx = <FarmTransaction>[];
  void add(TransactionType type, TransactionCategory c, double amount, int daysAgo,
      String? plot, String note) {
    tx.add(FarmTransaction(id: id('t'), type: type, category: c, amount: amount,
        date: d(daysAgo), plotId: plot, note: note));
  }

  const e = TransactionType.expense;
  add(e, TransactionCategory.seeds, 4200, 150, 'demo_p1', 'Тухмии пахта');
  add(e, TransactionCategory.fertilizer, 6800, 120, 'demo_p1', 'Карбамид, аммофос');
  add(e, TransactionCategory.fuel, 2400, 115, 'demo_p1', 'Шудгор');
  add(e, TransactionCategory.labor, 5000, 60, 'demo_p1', 'Чопиқ');
  add(e, TransactionCategory.water, 1800, 45, 'demo_p1', 'Пардохти об');
  add(e, TransactionCategory.pesticide, 2100, 25, 'demo_p1', 'Зидди ширинча');
  add(e, TransactionCategory.seeds, 3300, 35, 'demo_p2', 'Тухмии гандум «Сомон»');
  add(e, TransactionCategory.fertilizer, 2700, 28, 'demo_p2', 'Аммофос');
  add(e, TransactionCategory.seeds, 9600, 145, 'demo_p3', 'Тухмии картошка');
  add(e, TransactionCategory.labor, 4000, 42, 'demo_p3', 'Кофтан');
  add(e, TransactionCategory.equipment, 3500, 90, 'demo_p4', 'Системаи қатрагӣ');
  add(e, TransactionCategory.rent, 6000, 170, null, 'Иҷораи трактор');
  add(TransactionType.income, TransactionCategory.subsidy, 5000, 100, null, 'Грант барои қатрагӣ');

  final txJson = tx.map((x) => x.toJson()).toList();
  for (final h in harvests) {
    txJson.add(FarmTransaction(
      id: '${h.id}_inc',
      type: TransactionType.income,
      category: TransactionCategory.sale,
      amount: h.totalValue,
      date: h.date,
      plotId: h.plotId,
      harvestId: h.id,
      note: '${h.cropName} ${h.quantityKg.round()} кг',
    ).toJson());
  }

  return {
    'schema': 1,
    'plots': plots.map((x) => x.toJson()).toList(),
    'cycles': cycles.map((x) => x.toJson()).toList(),
    'irrigations': irrigations.map((x) => x.toJson()).toList(),
    'transactions': txJson,
    'harvests': harvests.map((x) => x.toJson()).toList(),
    'scans': const <Map<String, dynamic>>[],
  };
}
