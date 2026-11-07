import 'package:agro_ai/app.dart';
import 'package:agro_ai/data/local/farm_store.dart';
import 'package:agro_ai/data/local/local_store.dart';
import 'package:agro_ai/data/repositories/farm_repository.dart';
import 'package:agro_ai/main.dart';
import 'package:agro_ai/services/demo_data.dart';
import 'package:agro_ai/services/notification_service.dart';
import 'package:agro_ai/services/weather_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo farm loads consistently and gives live charts', () async {
    final repo = FarmRepository(JsonFarmStore(MemoryStore()));
    await repo.load();
    final now = DateTime(2026, 11, 7);
    await repo.replaceAll(buildDemoFarm(now: now));
    expect(repo.plots.length, 4);
    expect(repo.totalAreaHa, closeTo(9.6, 1e-9));
    expect(repo.upcomingIrrigations(now: now), isNotEmpty);
    // каждая продажа урожая связана с доходом
    for (final h in repo.harvests) {
      expect(repo.harvestHasIncome(h.id), isTrue);
    }
    final months = repo.monthlyTotals(now: now);
    expect(months.length, 6);
    expect(months.last.month, DateTime(2026, 11, 1));
    expect(months.any((m) => m.income > 0), isTrue);
    expect(months.any((m) => m.expense > 0), isTrue);
    final total = months.fold<double>(0, (s, m) => s + m.income);
    expect(total, lessThanOrEqualTo(repo.summary().income));
  });

  group('irrigation advice from forecast', () {
    DayForecast day(double tMax, double tMin, double rain, double et0) => DayForecast(
        date: DateTime(2026, 7, 1), tMax: tMax, tMin: tMin, rainMm: rain, et0Mm: et0, code: 0);

    test('rain soon → skip', () {
      expect(adviseIrrigation([day(30, 18, 4, 5), day(28, 17, 3, 4), day(30, 18, 0, 6)]).advice,
          IrrigationAdvice.skipRain);
    });
    test('hot and dry → water needed or heat warning', () {
      expect(adviseIrrigation([day(36, 22, 0, 7), day(36, 22, 0, 7), day(35, 21, 0, 7)]).advice,
          IrrigationAdvice.waterNeeded);
      expect(adviseIrrigation([day(41, 25, 0, 8), day(40, 25, 0, 8), day(39, 24, 0, 8)]).advice,
          IrrigationAdvice.heat);
    });
    test('frost', () {
      expect(adviseIrrigation([day(8, -2, 0, 1), day(9, 1, 0, 1), day(10, 2, 0, 1)]).advice,
          IrrigationAdvice.frost);
    });
    test('parse Open-Meteo response', () {
      final w = WeatherService.parse('Душанбе', {
        'current': {
          'temperature_2m': 31.4,
          'relative_humidity_2m': 22,
          'weather_code': 0,
          'wind_speed_10m': 9.1,
        },
        'daily': {
          'time': ['2026-07-01', '2026-07-02'],
          'temperature_2m_max': [36.0, 37.5],
          'temperature_2m_min': [21.0, 22.0],
          'precipitation_sum': [0, 0.2],
          'et0_fao_evapotranspiration': [7.1, 7.4],
          'weather_code': [0, 1],
        },
      });
      expect(w.temp, 31.4);
      expect(w.days.length, 2);
      expect(w.days[1].et0Mm, 7.4);
      expect(weatherEmoji(0), '☀️');
    });
  });

  testWidgets('first launch shows onboarding, then the dashboard', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final services = await tester.runAsync(() => bootstrap(
          store: MemoryStore(),
          notifications: NoopNotificationService(),
          loadModel: false,
        ));
    await tester.pumpWidget(AgroApp(services: services!));
    await tester.pumpAndSettle();
    expect(find.text('Хоҷагии шумо дар кафи даст'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ob_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ob_next')));
    await tester.pumpAndSettle();
    expect(find.text('Оғоз'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('ob_next')));
    });
    await tester.pumpAndSettle();
    expect(services.settings.value.onboarded, isTrue);
    expect(find.textContaining('Хоҷагии шумо имрӯз'), findsOneWidget);

    // Демо-хозяйство одной кнопкой → графики на главной.
    await tester.runAsync(() async {
      await tester.tap(find.text('Бор кардан'));
    });
    await tester.pumpAndSettle();
    expect(services.farm.plots.length, 4);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Даромад ва хароҷот (6 моҳ)'), findsOneWidget);
  });
}
