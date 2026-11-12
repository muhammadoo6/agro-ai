import 'dart:convert';
import 'dart:io';

import '../core/utils/id.dart';
import '../data/remote/claude_api_client.dart';
import '../data/remote/gemini_api_client.dart';
import '../data/repositories/settings_repository.dart' show AiProvider;
import '../features/knowledge/crop_guide.dart';
import '../models/plant_scan.dart';

/// Таҳлили акси растанӣ тавассути AI-и беруна (версияи online).
///
/// Провайдер: Gemini (ройгон) ё Claude. Агар калид набошад — маслиҳати офлайн
/// аз донишнома.
class AiService {
  AiService({ClaudeApiClient? client, GeminiApiClient? gemini})
      : _client = client ?? ClaudeApiClient(),
        _gemini = gemini ?? GeminiApiClient();

  final ClaudeApiClient _client;
  final GeminiApiClient _gemini;

  /// Проверка ключа Gemini: возвращает имя модели, которая ответила.
  Future<String> checkGeminiKey(String key) => _gemini.checkKey(key.trim());

  static const _schema = {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'is_plant': {'type': 'boolean'},
      'crop': {'type': 'string'},
      'is_healthy': {'type': 'boolean'},
      'diagnosis': {'type': 'string'},
      'confidence': {'type': 'number'},
      'severity': {
        'type': 'string',
        'enum': ['none', 'low', 'medium', 'high'],
      },
      'symptoms': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'recommendations': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'prevention': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': [
      'is_plant',
      'crop',
      'is_healthy',
      'diagnosis',
      'confidence',
      'severity',
      'symptoms',
      'recommendations',
      'prevention',
    ],
  };

  static String _system(String lang) {
    final language = lang == 'ru' ? 'русском' : 'таджикском (кириллица)';
    return '''
Ты — опытный агроном-фитопатолог, который помогает мелким фермерам Таджикистана.
По фотографии растения определи культуру, состояние и наиболее вероятную болезнь,
вредителя или дефицит питания. Учитывай климат Таджикистана (жаркое сухое лето,
поливное земледелие, засоление почв) и доступные там средства.

Правила:
- Пиши все текстовые поля на $language языке простыми словами для фермера.
- confidence — число от 0 до 1. Если фото нечёткое или не растение, снижай его.
- Если на фото не растение, верни is_plant=false и объясни в diagnosis.
- Рекомендации: сначала агротехнические и биологические меры, затем препараты
  по действующему веществу (без торговых марок) с напоминанием соблюдать
  инструкцию и средства защиты. 3–6 коротких пунктов.
- Не выдумывай: если не уверен, так и скажи и посоветуй обратиться к агроному.
''';
  }

  Future<PlantScan> analyze({
    required File image,
    required String savedImagePath,
    required String apiKey,
    required String lang,
    AiProvider provider = AiProvider.claude,
    String? cropHint,
    String? plotId,
    KnowledgeBase? knowledge,
  }) async {
    if (apiKey.trim().isEmpty) {
      return offlineAdvice(
        imagePath: savedImagePath,
        lang: lang,
        cropHint: cropHint,
        plotId: plotId,
        knowledge: knowledge,
      );
    }

    final bytes = await image.readAsBytes();
    final prompt = StringBuffer('Проанализируй растение на фото.');
    if (cropHint != null && cropHint.trim().isNotEmpty) {
      prompt.write(' Фермер говорит, что это: ${cropHint.trim()}.');
    }

    final j = provider == AiProvider.gemini
        ? await _gemini.analyzeImage(
            apiKey: apiKey.trim(),
            base64Image: base64Encode(bytes),
            mediaType: _mediaType(image.path),
            system: _system(lang),
            prompt: prompt.toString(),
            schema: _schema,
          )
        : await _client.analyzeImage(
            apiKey: apiKey.trim(),
            base64Image: base64Encode(bytes),
            mediaType: _mediaType(image.path),
            system: _system(lang),
            prompt: prompt.toString(),
            schema: _schema,
          );
    return fromAiJson(
      j,
      imagePath: savedImagePath,
      plotId: plotId,
      cropHint: cropHint,
    );
  }

  /// Табдили ҷавоби JSON-и AI ба [PlantScan].
  static PlantScan fromAiJson(
    Map<String, dynamic> j, {
    required String imagePath,
    String? plotId,
    String? cropHint,
  }) {
    List<String> list(String k) =>
        ((j[k] as List?) ?? const []).map((e) => '$e').where((e) => e.isNotEmpty).toList();
    final crop = (j['crop'] as String?)?.trim();
    final conf = (j['confidence'] as num?)?.toDouble() ?? 0;
    return PlantScan(
      id: newId(),
      imagePath: imagePath,
      date: DateTime.now(),
      plotId: plotId,
      cropName: (crop == null || crop.isEmpty) ? cropHint : crop,
      diagnosis: (j['diagnosis'] as String?) ?? '',
      isHealthy: j['is_healthy'] == true,
      confidence: conf.clamp(0, 1).toDouble(),
      severity: Severity.values.firstWhere(
        (s) => s.name == j['severity'],
        orElse: () => Severity.none,
      ),
      symptoms: list('symptoms'),
      recommendations: list('recommendations'),
      prevention: list('prevention'),
      source: ScanSource.ai,
    );
  }

  /// Маслиҳати офлайн: бемориҳои маъмули зироат аз донишнома.
  static PlantScan offlineAdvice({
    required String imagePath,
    required String lang,
    String? cropHint,
    String? plotId,
    KnowledgeBase? knowledge,
  }) {
    final guide = knowledge?.findByName(cropHint);
    final ru = lang == 'ru';
    final symptoms = <String>[];
    final recs = <String>[];
    if (guide != null) {
      for (final d in guide.diseases) {
        symptoms.add('${d.name}: ${d.signs}');
        recs.add('${d.name}: ${d.treatment}');
      }
    } else {
      recs.addAll(ru
          ? [
              'Осмотрите нижнюю сторону листьев: нет ли тли, клещей, паутины.',
              'Пятна с жёлтым ободком часто означают грибковую болезнь — удалите больные листья.',
              'Пожелтение старых листьев — часто недостаток азота; молодых — железа или влаги.',
              'Не поливайте по листьям вечером, проветривайте посадки.',
              'Для точного диагноза введите ключ AI в настройках или покажите растение агроному.',
            ]
          : [
              'Тарафи поёни баргро бинед: шира, кана ё тор ҳаст ё не.',
              'Доғҳо бо ҳошияи зард аксаран бемории занбӯруғӣ аст — баргҳои беморро канда партоед.',
              'Зард шудани баргҳои кӯҳна — аксаран норасоии нитроген; баргҳои ҷавон — оҳан ё намӣ.',
              'Бегоҳӣ ба болои барг об напошед, киштро ҳаво диҳед.',
              'Барои ташхиси дақиқ калиди AI-ро дар танзимот ворид кунед ё растаниро ба агроном нишон диҳед.',
            ]);
    }
    return PlantScan(
      id: newId(),
      imagePath: imagePath,
      date: DateTime.now(),
      plotId: plotId,
      cropName: guide?.name ?? cropHint,
      diagnosis: guide != null
          ? (ru
              ? 'Частые проблемы культуры «${guide.name}». Сравните с вашим растением.'
              : 'Мушкилоти маъмули зироати «${guide.name}». Бо растании худ муқоиса кунед.')
          : (ru ? 'Общие советы по осмотру растения' : 'Маслиҳатҳои умумӣ барои муоинаи растанӣ'),
      isHealthy: false,
      confidence: 0,
      severity: Severity.none,
      symptoms: symptoms,
      recommendations: recs,
      prevention: guide?.tips ?? const [],
      source: ScanSource.offline,
    );
  }

  static String _mediaType(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
