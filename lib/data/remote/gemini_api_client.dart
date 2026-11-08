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

  final http.Client _http;
  final String baseUrl;

  Future<Map<String, dynamic>> analyzeImage({
    required String apiKey,
    required String base64Image,
    required String mediaType,
    required String system,
    required String prompt,
    required Map<String, dynamic> schema,
    String model = defaultModel,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final body = {
      'systemInstruction': {
        'parts': [
          {'text': system},
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

    http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('$baseUrl/v1beta/models/$model:generateContent'),
            headers: {
              'content-type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on Exception catch (e) {
      throw ClaudeApiException('network: $e', retryable: true);
    }

    final text = utf8.decode(res.bodyBytes);
    if (res.statusCode == 404 && model != fallbackModel) {
      return analyzeImage(
        apiKey: apiKey,
        base64Image: base64Image,
        mediaType: mediaType,
        system: system,
        prompt: prompt,
        schema: schema,
        model: fallbackModel,
        timeout: timeout,
      );
    }
    if (res.statusCode != 200) {
      var msg = 'HTTP ${res.statusCode}';
      try {
        final err = jsonDecode(text) as Map<String, dynamic>;
        msg = '${err['error']?['status'] ?? msg}: ${err['error']?['message'] ?? ''}';
      } catch (_) {}
      throw ClaudeApiException(
        msg,
        statusCode: res.statusCode,
        retryable: res.statusCode == 429 || res.statusCode >= 500,
      );
    }

    final data = jsonDecode(text) as Map<String, dynamic>;
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
    final out = parts
        .whereType<Map>()
        .where((p) => p['thought'] != true && p['text'] is String)
        .map((p) => p['text'] as String)
        .join();
    if (out.isEmpty) throw ClaudeApiException('empty response');
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
