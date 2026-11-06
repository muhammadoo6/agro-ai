import 'dart:convert';

import 'package:http/http.dart' as http;

class ClaudeApiException implements Exception {
  ClaudeApiException(this.message, {this.statusCode, this.retryable = false});
  final String message;
  final int? statusCode;
  final bool retryable;

  @override
  String toString() => message;
}

/// Пайвастшавӣ ба Claude Messages API (HTTP, чунки SDK-и расмӣ барои Dart нест).
class ClaudeApiClient {
  ClaudeApiClient({http.Client? httpClient, this.baseUrl = 'https://api.anthropic.com'})
      : _http = httpClient ?? http.Client();

  static const model = 'claude-opus-5-5';
  static const apiVersion = '2026-10-21';
  static const fallbackBeta = 'server-side-fallback-2026-07-01';

  final http.Client _http;
  final String baseUrl;

  /// Дархост бо акс ва ҷавоби JSON аз рӯи [schema].
  Future<Map<String, dynamic>> analyzeImage({
    required String apiKey,
    required String base64Image,
    required String mediaType,
    required String system,
    required String prompt,
    required Map<String, dynamic> schema,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final body = {
      'model': model,
      'max_tokens': 16000,
      'system': system,
      'output_config': {
        'effort': 'medium',
        'format': {'type': 'json_schema', 'schema': schema},
      },
      // Агар модел дархостро рад кунад, сервер худаш модели дигарро интихоб мекунад.
      'fallbacks': 'default',
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaType,
                'data': base64Image,
              },
            },
            {'type': 'text', 'text': prompt},
          ],
        },
      ],
    };

    http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('$baseUrl/v1/messages'),
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': apiVersion,
              'anthropic-beta': fallbackBeta,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on Exception catch (e) {
      throw ClaudeApiException('network: $e', retryable: true);
    }

    final text = utf8.decode(res.bodyBytes);
    if (res.statusCode != 200) {
      String msg = 'HTTP ${res.statusCode}';
      try {
        final err = jsonDecode(text) as Map<String, dynamic>;
        msg = '${err['error']?['type'] ?? msg}: ${err['error']?['message'] ?? ''}';
      } catch (_) {}
      throw ClaudeApiException(
        msg,
        statusCode: res.statusCode,
        retryable: res.statusCode == 429 || res.statusCode >= 500,
      );
    }

    final data = jsonDecode(text) as Map<String, dynamic>;
    final stop = data['stop_reason'];
    if (stop == 'refusal') {
      throw ClaudeApiException('refusal');
    }
    if (stop == 'max_tokens') {
      throw ClaudeApiException('max_tokens');
    }
    final content = (data['content'] as List?) ?? const [];
    final textBlock = content.cast<Map<String, dynamic>>().firstWhere(
          (b) => b['type'] == 'text',
          orElse: () => const {},
        );
    final out = textBlock['text'];
    if (out is! String || out.isEmpty) {
      throw ClaudeApiException('empty response');
    }
    try {
      return jsonDecode(out) as Map<String, dynamic>;
    } catch (_) {
      throw ClaudeApiException('invalid JSON');
    }
  }

  void close() => _http.close();
}
