import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../services/weather_service.dart';

const _wd = {
  'tg': ['Дш', 'Сш', 'Чш', 'Пш', 'Ҷм', 'Шб', 'Яш'],
  'ru': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
};

/// Погода и совет по поливу (только онлайн-версия).
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  Future<Weather>? _future;
  String? _city;

  void _load({bool force = false}) {
    final s = AppScope.of(context);
    final w = s.weather;
    if (w == null) return;
    _city = s.settings.value.weatherCity;
    _future = w.forecast(_city!, force: force);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future == null) _load();
  }

  Future<void> _pickCity() async {
    final s = AppScope.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in tajikCities.keys)
              ListTile(
                title: Text(c),
                trailing: c == _city ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await s.settings.update(s.settings.value.copyWith(weatherCity: picked));
    setState(() => _load(force: true));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (s.weather == null) return const SizedBox.shrink();
    final l = context.l;
    final lang = s.settings.value.languageCode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: FutureBuilder<Weather>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 90,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (snap.hasError || snap.data == null) {
              return ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: Text(l.t('weather_unavailable')),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => setState(() => _load(force: true)),
                ),
              );
            }
            final w = snap.data!;
            final adv = adviseIrrigation(w.days);
            final (advText, advColor, advIcon) = switch (adv.advice) {
              IrrigationAdvice.skipRain => (
                  l.f('adv_rain', [adv.mm.toStringAsFixed(0)]),
                  AppColors.water,
                  Icons.umbrella_outlined
                ),
              IrrigationAdvice.waterNeeded => (
                  l.f('adv_water', [adv.mm.toStringAsFixed(0)]),
                  AppColors.warning,
                  Icons.water_drop
                ),
              IrrigationAdvice.heat => (l.t('adv_heat'), AppColors.expense, Icons.wb_sunny),
              IrrigationAdvice.frost => (l.t('adv_frost'), const Color(0xFF1565C0), Icons.ac_unit),
              IrrigationAdvice.normal => (
                  l.f('adv_normal', [adv.mm.toStringAsFixed(0)]),
                  AppColors.primary,
                  Icons.check_circle_outline
                ),
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0277BD), Color(0xFF29B6F6)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(weatherEmoji(w.code), style: const TextStyle(fontSize: 36)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${w.temp.round()}°C',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800)),
                            Text(
                              '💧 ${w.humidity.round()}%  ·  💨 ${w.wind.round()} км/ч',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        onPressed: _pickCity,
                        icon: const Icon(Icons.place_outlined, size: 18),
                        label: Text(w.city),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      for (final d in w.days)
                        Expanded(
                          child: Column(
                            children: [
                              Text((_wd[lang] ?? _wd['tg']!)[d.date.weekday - 1],
                                  style: Theme.of(context).textTheme.labelSmall),
                              Text(weatherEmoji(d.code), style: const TextStyle(fontSize: 20)),
                              Text('${d.tMax.round()}°/${d.tMin.round()}°',
                                  style: Theme.of(context).textTheme.labelSmall),
                              if (d.rainMm >= 0.5)
                                Text('${d.rainMm.toStringAsFixed(0)} мм',
                                    style: const TextStyle(
                                        fontSize: 10, color: AppColors.water)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: advColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(advIcon, color: advColor),
                      const SizedBox(width: 8),
                      Expanded(child: Text(advText)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
