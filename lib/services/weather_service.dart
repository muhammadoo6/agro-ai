import 'dart:convert';

import 'package:http/http.dart' as http;

/// Города Таджикистана для прогноза (без GPS — не нужны разрешения).
const tajikCities = <String, (double, double)>{
  'Душанбе': (38.56, 68.77),
  'Хуҷанд': (40.28, 69.62),
  'Бохтар': (37.84, 68.78),
  'Кӯлоб': (37.91, 69.78),
  'Ҳисор': (38.53, 68.55),
  'Истаравшан': (39.91, 69.00),
  'Панҷакент': (39.50, 67.61),
  'Турсунзода': (38.51, 68.23),
  'Ваҳдат': (38.56, 69.02),
  'Хоруғ': (37.49, 71.55),
  'Исфара': (40.13, 70.63),
  'Данғара': (38.10, 69.33),
};

class DayForecast {
  const DayForecast({
    required this.date,
    required this.tMax,
    required this.tMin,
    required this.rainMm,
    required this.et0Mm,
    required this.code,
  });

  final DateTime date;
  final double tMax, tMin, rainMm, et0Mm;
  final int code;
}

class Weather {
  const Weather({
    required this.city,
    required this.temp,
    required this.humidity,
    required this.wind,
    required this.code,
    required this.days,
    required this.fetchedAt,
  });

  final String city;
  final double temp, humidity, wind;
  final int code;
  final List<DayForecast> days;
  final DateTime fetchedAt;
}

enum IrrigationAdvice { skipRain, waterNeeded, normal, heat, frost }

/// Простое правило совета по поливу на ближайшие дни.
({IrrigationAdvice advice, double mm}) adviseIrrigation(List<DayForecast> days) {
  if (days.isEmpty) return (advice: IrrigationAdvice.normal, mm: 0);
  final next = days.take(3).toList();
  final rain2 = days.take(2).fold<double>(0, (s, d) => s + d.rainMm);
  final et3 = next.fold<double>(0, (s, d) => s + d.et0Mm);
  final rain3 = next.fold<double>(0, (s, d) => s + d.rainMm);
  if (next.any((d) => d.tMin <= 0)) return (advice: IrrigationAdvice.frost, mm: 0);
  if (rain2 >= 5) return (advice: IrrigationAdvice.skipRain, mm: rain2);
  if (next.any((d) => d.tMax >= 38)) return (advice: IrrigationAdvice.heat, mm: et3 - rain3);
  final deficit = et3 - rain3;
  if (deficit >= 12) return (advice: IrrigationAdvice.waterNeeded, mm: deficit);
  return (advice: IrrigationAdvice.normal, mm: deficit < 0 ? 0 : deficit);
}

/// Прогноз Open-Meteo (бесплатно, без ключа; данные CC BY 4.0).
class WeatherService {
  WeatherService({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  Weather? _cache;

  Future<Weather> forecast(String city, {bool force = false}) async {
    final c = _cache;
    if (!force &&
        c != null &&
        c.city == city &&
        DateTime.now().difference(c.fetchedAt) < const Duration(minutes: 30)) {
      return c;
    }
    final (lat, lon) = tajikCities[city] ?? tajikCities['Душанбе']!;
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$lat',
      'longitude': '$lon',
      'current': 'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m',
      'daily':
          'temperature_2m_max,temperature_2m_min,precipitation_sum,et0_fao_evapotranspiration,weather_code',
      'timezone': 'Asia/Dushanbe',
      'forecast_days': '5',
    });
    final res = await _http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('weather HTTP ${res.statusCode}');
    final w = parse(city, jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
    _cache = w;
    return w;
  }

  static Weather parse(String city, Map<String, dynamic> j) {
    final cur = Map<String, dynamic>.from(j['current'] as Map);
    final d = Map<String, dynamic>.from(j['daily'] as Map);
    double at(String k, int i) => ((d[k] as List)[i] as num?)?.toDouble() ?? 0;
    final times = (d['time'] as List).cast<String>();
    return Weather(
      city: city,
      temp: (cur['temperature_2m'] as num).toDouble(),
      humidity: (cur['relative_humidity_2m'] as num?)?.toDouble() ?? 0,
      wind: (cur['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      code: (cur['weather_code'] as num?)?.toInt() ?? 0,
      days: [
        for (var i = 0; i < times.length; i++)
          DayForecast(
            date: DateTime.parse(times[i]),
            tMax: at('temperature_2m_max', i),
            tMin: at('temperature_2m_min', i),
            rainMm: at('precipitation_sum', i),
            et0Mm: at('et0_fao_evapotranspiration', i),
            code: ((d['weather_code'] as List)[i] as num?)?.toInt() ?? 0,
          ),
      ],
      fetchedAt: DateTime.now(),
    );
  }
}

/// WMO weather code → значок.
String weatherEmoji(int code) {
  if (code == 0) return '☀️';
  if (code <= 2) return '🌤️';
  if (code == 3) return '☁️';
  if (code == 45 || code == 48) return '🌫️';
  if (code >= 51 && code <= 67) return '🌧️';
  if (code >= 71 && code <= 77) return '❄️';
  if (code >= 80 && code <= 82) return '🌦️';
  if (code >= 95) return '⛈️';
  return '🌡️';
}
