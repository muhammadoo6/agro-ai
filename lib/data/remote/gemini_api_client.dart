import 'dart:convert';

import 'package:http/http.dart' as http;

import 'claude_api_client.dart' show ClaudeApiException;

/// Google Gemini API (бесплатный уровень доступен для `gemini-3.8-flash`).
///
/// Ключ бесплатно выдаётся на https://aistudio.google.com/apikey.
/// Внимание: на бесплатном уровне Google может использовать запросы для
/// улучшения своих продуктов.
class GeminiApiClient {
  GeminiApiClient({
    http.Client? httpClient,
    this.baseUrl = 'https://generativelanguage.googleapis.com',
  }) : _http = httpClient ?? http.Client();

  static const defaultModel = 'gemini-3.8-flash';

  /// Запасная модель, если основную переименуют или уберут (HTTP 404).
  static const fallbackModel = 'gemini-flash-latest';

  /// Порядок перебора. На бесплатном ключе часть моделей закрыта (лимит 0)
  /// или переименована, поэтому пробуем по очереди, пока одна не ответит.
  static const preferredModels = [
    defaultModel,
    fallbackModel,
    'gemini-flash-lite-latest',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash',
  ];

  final http.Client _http;
  final String baseUrl;

  /// Модель, которая уже ответила этому ключу (чтобы не перебирать заново).
  String? _workingModel;
  String? _workingKey;
  bool _bearer = false;

  Map<String, String> _headers(String apiKey) => {
        'content-type': 'application/json',
        if (_bearer) 'authorization': 'Bearer $apiKey' else 'x-goog-api-key': apiKey,
      };

  static ClaudeApiException _error(http.Response res) {
    var status = 'HTTP ${res.statusCode}';
    var message = '';
    try {
      final err = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      status = '${err['error']?['status'] ?? status}';
      message = '${err['error']?['message'] ?? ''}';
    } catch (_) {}
    final low = message.toLowerCase();
    String msg;
    if (low.contains('api key not valid') ||
        low.contains('api_key_invalid') ||
        res.statusCode == 401) {
      msg = 'bad_key';
    } else if (low.contains('location is not supported')) {
      msg = 'region';
    } else if (res.statusCode == 429) {
      msg = 'quota';
    } else {
      msg = message.isEmpty ? status : '$status: $message';
    }
    return ClaudeApiException(
      msg,
      statusCode: res.statusCode,
      retryable: res.statusCode == 429 || res.statusCode >= 500,
    );
  }

  /// Модели, доступные этому ключу (умеют generateContent).
  Future<List<String>> listModels(String apiKey,
      {Duration timeout = const Duration(seconds: 20)}) async {
    http.Response res;
    try {
      res = await _http
          .get(Uri.parse('$baseUrl/v1beta/models?pageSize=1000'),
              headers: _headers(apiKey))
          .timeout(timeout);
    } on Exception catch (e) {
      throw ClaudeApiException('network: $e', retryable: true);
    }
    if (res.statusCode != 200) throw _error(res);
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final names = <String>[];
    for (final m in (data['models'] as List?) ?? const []) {
      if (m is! Map) continue;
      final methods = (m['supportedGenerationMethods'] as List?) ?? const [];
      if (!methods.contains('generateContent')) continue;
      final name = '${m['name']}'.replaceFirst('models/', '');
      if (_usable(name)) names.add(name);
    }
    return names;
  }

  static bool _usable(String n) {
    if (!n.startsWith('gemini')) return false;
    const skip = ['image', 'tts', 'audio', 'live', 'embedding', 'robotics', 'computer-use'];
    return !skip.any(n.contains);
  }

  static int _rank(String n) {
    final i = preferredModels.indexOf(n);
    if (i >= 0) return i;
    if (n.contains('flash') && !n.contains('lite')) return 20;
    if (n.contains('flash')) return 30;
    return 40; // pro: на бесплатном ключе обычно закрыты
  }

  Future<List<String>> _candidates(String apiKey) async {
    if (_workingModel != null && _workingKey == apiKey) return [_workingModel!];
    List<String> available = const [];
    try {
      available = await listModels(apiKey);
    } on ClaudeApiException catch (e) {
      if (e.message == 'bad_key' && !_bearer && !apiKey.startsWith('AIza')) {
        // Ключи нового формата могут приниматься как токен.
        _bearer = true;
        try {
          available = await listModels(apiKey);
        } on ClaudeApiException {
          _bearer = false;
          throw e;
        }
      } else if (e.message == 'bad_key' || e.message == 'region') {
        rethrow;
      }
      // Иначе (сеть, 5xx) — пробуем известные имена напрямую.
    }
    if (available.isEmpty) return preferredModels;
    final list = [...available]..sort((a, b) {
        final r = _rank(a).compareTo(_rank(b));
        return r != 0 ? r : b.compareTo(a); // новее — раньше
      });
    return list.take(8).toList();
  }

  Future<http.Response> _post(String apiKey, String model, Map<String, dynamic> body,
      Duration timeout) async {
    try {
      return await _http
          .post(Uri.parse('$baseUrl/v1beta/models/$model:generateContent'),
              headers: _headers(apiKey), body: jsonEncode(body))
          .timeout(timeout);
    } on Exception catch (e) {
      throw ClaudeApiException('network: $e', retryable: true);
    }
  }

  /// Отправляет запрос, перебирая модели, пока одна не ответит 200.
  Future<http.Response> _generate(String apiKey, Map<String, dynamic> body,
      Duration timeout) async {
    final models = await _candidates(apiKey);
    ClaudeApiException? last;
    for (final model in models) {
      var res = await _post(apiKey, model, body, timeout);
      if (res.statusCode == 400 &&
          (body['generationConfig'] as Map?)?.containsKey('responseSchema') == true) {
        final e = _error(res);
        if (e.message != 'bad_key' && e.message != 'region') {
          // Модель не приняла схему — просим просто JSON.
          final plain = Map<String, dynamic>.from(body)
            ..['generationConfig'] = {'responseMimeType': 'application/json'};
          res = await _post(apiKey, model, plain, timeout);
        }
      }
      if (res.statusCode == 200) {
        _workingModel = model;
        _workingKey = apiKey;
        return res;
      }
      last = _error(res);
      if (last.message == 'bad_key' || last.message == 'region') throw last;
      // 404 (нет модели), 429 (лимит этой модели), 403, 5xx — следующая.
    }
    _workingModel = null;
    throw last ?? ClaudeApiException('empty response');
  }

  /// Проверка ключа: короткий текстовый запрос. Возвращает имя модели,
  /// которая ответила; иначе бросает [ClaudeApiException] с причиной.
  Future<String> checkKey(String apiKey,
      {Duration timeout = const Duration(seconds: 30)}) async {
    _workingModel = null;
    _bearer = false;
    await _generate(
      apiKey,
      {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': 'ok'},
            ],
          },
        ],
      },
      timeout,
    );
    return _workingModel!;
  }

  Future<Map<String, dynamic>> analyzeImage({
    required String apiKey,
    required String base64Image,
    required String mediaType,
    required String system,
    required String prompt,
    required Map<String, dynamic> schema,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final keys = ((schema['properties'] as Map?) ?? const {}).keys.join(', ');
    final body = {
      'systemInstruction': {
        'parts': [
          {'text': keys.isEmpty ? system : '$system\nОтвет — один JSON-объект с полями: $keys.'},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'inline_data': {'mime_type': mediaType, 'data': base64Image},
            },
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': toGeminiSchema(schema),
      },
    };

    final res = await _generate(apiKey, body, timeout);
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final candidates = (data['candidates'] as List?) ?? const [];
    if (candidates.isEmpty) {
      final reason = data['promptFeedback']?['blockReason'];
      throw ClaudeApiException(reason == null ? 'empty response' : 'refusal');
    }
    final cand = Map<String, dynamic>.from(candidates.first as Map);
    final finish = cand['finishReason'];
    if (finish == 'SAFETY' || finish == 'PROHIBITED_CONTENT') {
      throw ClaudeApiException('refusal');
    }
    if (finish == 'MAX_TOKENS') throw ClaudeApiException('max_tokens');
    final parts = (cand['content']?['parts'] as List?) ?? const [];
    var out = parts
        .whereType<Map>()
        .where((p) => p['thought'] != true && p['text'] is String)
        .map((p) => p['text'] as String)
        .join()
        .trim();
    if (out.isEmpty) throw ClaudeApiException('empty response');
    // Без схемы модель иногда оборачивает JSON в блок кода.
    final a = out.indexOf('{'), b = out.lastIndexOf('}');
    if (a > 0 && b > a) out = out.substring(a, b + 1);
    try {
      return jsonDecode(out) as Map<String, dynamic>;
    } catch (_) {
      throw ClaudeApiException('invalid JSON');
    }
  }

  /// JSON Schema → схема Gemini (OpenAPI-подмножество: без additionalProperties).
  static Map<String, dynamic> toGeminiSchema(Map<String, dynamic> s) {
    final out = <String, dynamic>{};
    s.forEach((k, v) {
      if (k == 'additionalProperties') return;
      if (k == 'type' && v is String) {
        out[k] = v.toUpperCase();
      } else if (k == 'properties' && v is Map) {
        out[k] = v.map((pk, pv) =>
            MapEntry(pk as String, toGeminiSchema(Map<String, dynamic>.from(pv as Map))));
      } else if (k == 'items' && v is Map) {
        out[k] = toGeminiSchema(Map<String, dynamic>.from(v));
      } else {
        out[k] = v;
      }
    });
    return out;
  }

  void close() => _http.close();
}
