import 'dart:convert';

import 'package:flutter/services.dart';

/// Як мақолаи донишнома дар бораи зироат.
class CropGuide {
  const CropGuide({
    required this.id,
    required this.name,
    this.nameRu = '',
    required this.latin,
    required this.icon,
    required this.category,
    required this.summary,
    required this.sowingTime,
    required this.soil,
    required this.watering,
    required this.fertilizing,
    required this.diseases,
    required this.harvesting,
    required this.tips,
    required this.growingDays,
  });

  final String id;
  final String name;

  /// Номи русӣ — барои ҷустуҷӯ ва интерфейси русӣ.
  final String nameRu;
  final String latin;
  final String icon;
  final String category;
  final String summary;
  final String sowingTime;
  final String soil;
  final String watering;
  final String fertilizing;
  final List<CropDisease> diseases;
  final String harvesting;
  final List<String> tips;

  /// Давомнокии тахминии парвариш (рӯз) — барои ҳисоби санаи ҳосил.
  final int growingDays;

  bool matches(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return true;
    return name.toLowerCase().contains(s) ||
        nameRu.toLowerCase().contains(s) ||
        latin.toLowerCase().contains(s) ||
        category.toLowerCase().contains(s) ||
        diseases.any((d) => d.name.toLowerCase().contains(s));
  }

  factory CropGuide.fromJson(Map<String, dynamic> j) => CropGuide(
        id: j['id'] as String,
        name: j['name'] as String,
        nameRu: (j['name_ru'] as String?) ?? '',
        latin: (j['latin'] as String?) ?? '',
        icon: (j['icon'] as String?) ?? '🌱',
        category: (j['category'] as String?) ?? '',
        summary: (j['summary'] as String?) ?? '',
        sowingTime: (j['sowing_time'] as String?) ?? '',
        soil: (j['soil'] as String?) ?? '',
        watering: (j['watering'] as String?) ?? '',
        fertilizing: (j['fertilizing'] as String?) ?? '',
        diseases: ((j['diseases'] as List?) ?? const [])
            .map((e) => CropDisease.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        harvesting: (j['harvesting'] as String?) ?? '',
        tips: ((j['tips'] as List?) ?? const []).map((e) => '$e').toList(),
        growingDays: (j['growing_days'] as num?)?.toInt() ?? 0,
      );
}

class CropDisease {
  const CropDisease({
    required this.name,
    required this.signs,
    required this.treatment,
  });

  final String name;
  final String signs;
  final String treatment;

  factory CropDisease.fromJson(Map<String, dynamic> j) => CropDisease(
        name: (j['name'] as String?) ?? '',
        signs: (j['signs'] as String?) ?? '',
        treatment: (j['treatment'] as String?) ?? '',
      );
}

/// Боркунии донишнома аз `assets/data/crop_guides_tg.json`.
class KnowledgeBase {
  KnowledgeBase(this.guides, [List<String> categories = const []])
      : categories = {...categories, for (final g in guides) g.category}.toList();

  final List<CropGuide> guides;

  /// Бахшҳо (Мевагӣ, Сабзавот, …) бо тартиби намоиш.
  final List<String> categories;

  /// Номи бахш ба русӣ (матни роҳнамоҳо тоҷикӣ мемонад).
  static const categoryRu = {
    'Ғалладона': 'Зерновые',
    'Сабзавот': 'Овощи',
    'Полизӣ': 'Бахчевые',
    'Мевагӣ': 'Фрукты',
    'Ангур ва буттамева': 'Виноград и ягоды',
    'Чормағз ва бодом': 'Орехи',
    'Лӯбиёгиҳо': 'Бобовые',
    'Зироати техникӣ': 'Технические',
    'Хӯроки чорво': 'Кормовые',
  };

  static const categoryIcon = {
    'Ғалладона': '🌾',
    'Сабзавот': '🥕',
    'Полизӣ': '🍉',
    'Мевагӣ': '🍎',
    'Ангур ва буттамева': '🍇',
    'Чормағз ва бодом': '🌰',
    'Лӯбиёгиҳо': '🫘',
    'Зироати техникӣ': '☁️',
    'Хӯроки чорво': '🌿',
  };

  static String categoryLabel(String c, String lang) =>
      lang == 'ru' ? (categoryRu[c] ?? c) : c;

  List<CropGuide> inCategory(String c) => guides.where((g) => g.category == c).toList();

  static const assetPath = 'assets/data/crop_guides_tg.json';

  static Future<KnowledgeBase> load([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    return parse(raw);
  }

  static KnowledgeBase parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final list = (j['crops'] as List)
        .map((e) => CropGuide.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final cats = ((j['categories'] as List?) ?? const []).map((e) => '$e').toList();
    return KnowledgeBase(list, cats);
  }

  List<CropGuide> search(String q) => guides.where((g) => g.matches(q)).toList();

  /// Ҷустуҷӯи мақола аз рӯи номи зироат (масалан, аз мавсими кишт).
  CropGuide? findByName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final s = name.trim().toLowerCase();
    for (final g in guides) {
      if (g.name.toLowerCase() == s || g.nameRu.toLowerCase() == s || g.id == s) return g;
    }
    for (final g in guides) {
      if (g.name.toLowerCase().contains(s) || s.contains(g.name.toLowerCase())) {
        return g;
      }
    }
    return null;
  }
}
