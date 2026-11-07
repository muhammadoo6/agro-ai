import 'dart:convert';

import 'package:flutter/services.dart';

/// Своя база болезней (assets/data/diseases_tg.json): описание каждого класса модели.
class DiseaseInfo {
  const DiseaseInfo({
    required this.label,
    required this.cropKey,
    required this.healthy,
    required this.severity,
    required this.name,
    required this.symptoms,
    required this.treatment,
    required this.prevention,
  });

  final String label;
  final String cropKey;
  final bool healthy;
  final String severity;
  final Map<String, String> name;
  final Map<String, List<String>> symptoms;
  final Map<String, List<String>> treatment;
  final Map<String, List<String>> prevention;

  String nameIn(String lang) => name[lang] ?? name['tg'] ?? label;
  List<String> symptomsIn(String lang) => symptoms[lang] ?? symptoms['tg'] ?? const [];
  List<String> treatmentIn(String lang) => treatment[lang] ?? treatment['tg'] ?? const [];
  List<String> preventionIn(String lang) => prevention[lang] ?? prevention['tg'] ?? const [];
}

class DiseaseBase {
  DiseaseBase._(Map<String, Map<String, dynamic>> diseases,
      Map<String, Map<String, String>> crops, this._healthy)
      : _diseases = {for (final e in diseases.entries) normalize(e.key): e.value},
        _crops = {for (final e in crops.entries) normalize(e.key): e.value};

  /// «Corn_(maize)___Common_rust_» и «Corn___Common_rust» → «corn___common_rust».
  static String normalize(String label) => label
      .toLowerCase()
      .replaceAll(RegExp(r'\([^)]*\)'), '')
      .split('___')
      .map((p) => p.replaceAll(RegExp(r'^[_,\s]+|[_,\s]+$'), ''))
      .join('___');

  static const assetPath = 'assets/data/diseases_tg.json';

  final Map<String, Map<String, dynamic>> _diseases;
  final Map<String, Map<String, String>> _crops;
  final Map<String, dynamic> _healthy;

  static Future<DiseaseBase> load([AssetBundle? bundle]) async =>
      parse(await (bundle ?? rootBundle).loadString(assetPath));

  static DiseaseBase parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final diseases = (j['diseases'] as Map).map(
        (k, v) => MapEntry(k as String, Map<String, dynamic>.from(v as Map)));
    final crops = (j['crops'] as Map).map((k, v) =>
        MapEntry(k as String, Map<String, String>.from(v as Map)));
    return DiseaseBase._(diseases, crops, Map<String, dynamic>.from(j['healthy_template'] as Map));
  }

  static String cropKeyOf(String label) => normalize(label).split('___').first;

  Iterable<String> get cropKeys => _crops.keys;

  String cropName(String cropKey, String lang) =>
      _crops[cropKey]?[lang] ?? _crops[cropKey]?['tg'] ?? cropKey;

  /// Название культуры, как ввёл пользователь → ключ культуры в модели.
  String? cropKeyFromHint(String? hint) {
    if (hint == null || hint.trim().isEmpty) return null;
    final h = hint.trim().toLowerCase();
    for (final e in _crops.entries) {
      for (final name in e.value.values) {
        for (final part in name.toLowerCase().split('/')) {
          final p = part.trim();
          if (p.isNotEmpty && (h.contains(p) || p.contains(h))) return e.key;
        }
      }
    }
    return null;
  }

  DiseaseInfo info(String label) {
    final crop = cropKeyOf(label);
    final healthy = label.toLowerCase().endsWith('___healthy');
    final d = healthy ? _healthy : (_diseases[normalize(label)] ?? const <String, dynamic>{});
    List<String> list(String key) =>
        ((d[key] as List?) ?? const []).map((e) => '$e').toList();
    return DiseaseInfo(
      label: label,
      cropKey: crop,
      healthy: healthy,
      severity: healthy ? 'none' : (d['severity'] as String? ?? 'medium'),
      name: {
        'tg': d['name_tg'] as String? ?? label,
        'ru': d['name_ru'] as String? ?? label,
      },
      symptoms: {'tg': list('symptoms_tg'), 'ru': list('symptoms_ru')},
      treatment: {'tg': list('treatment_tg'), 'ru': list('treatment_ru')},
      prevention: {'tg': list('prevention_tg'), 'ru': list('prevention_ru')},
    );
  }

  bool has(String label) =>
      label.toLowerCase().endsWith('___healthy') || _diseases.containsKey(normalize(label));
}
