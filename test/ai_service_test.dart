import 'dart:convert';
import 'dart:io';

import 'package:agro_ai/data/remote/claude_api_client.dart';
import 'package:agro_ai/features/knowledge/crop_guide.dart';
import 'package:agro_ai/models/plant_scan.dart';
import 'package:agro_ai/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final kb = KnowledgeBase.parse(
      File('assets/data/crop_guides_tg.json').readAsStringSync());

  Map<String, dynamic> aiResult() => {
        'is_plant': true,
        'crop': 'Помидор',
        'is_healthy': false,
        'diagnosis': 'Фитофтороз',
        'confidence': 0.82,
        'severity': 'medium',
        'symptoms': ['Доғҳои қаҳвагӣ'],
        'recommendations': ['Баргҳои беморро канед'],
        'prevention': ['Ҳаво додан'],
      };

  test('fromAiJson maps fields', () {
    final s = AiService.fromAiJson(aiResult(), imagePath: '/a.jpg', plotId: 'p');
    expect(s.cropName, 'Помидор');
    expect(s.isHealthy, isFalse);
    expect(s.severity, Severity.medium);
    expect(s.confidence, 0.82);
    expect(s.source, ScanSource.ai);
    expect(s.plotId, 'p');
  });

  test('offline advice uses knowledge base for known crop', () {
    final s = AiService.offlineAdvice(
        imagePath: '/a.jpg', lang: 'tg', cropHint: 'помидор', knowledge: kb);
    expect(s.source, ScanSource.offline);
    expect(s.cropName, 'Помидор');
    expect(s.recommendations, isNotEmpty);
  });

  test('offline advice works without crop', () {
    final s = AiService.offlineAdvice(imagePath: '/a.jpg', lang: 'ru', knowledge: kb);
    expect(s.recommendations.length, greaterThanOrEqualTo(3));
  });

  group('ClaudeApiClient', () {
    test('sends correct request and parses JSON output', () async {
      late http.Request captured;
      final client = ClaudeApiClient(
        httpClient: MockClient((req) async {
          captured = req;
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'stop_reason': 'end_turn',
              'content': [
                {'type': 'thinking', 'thinking': ''},
                {'type': 'text', 'text': jsonEncode(aiResult())},
              ],
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final out = await client.analyzeImage(
        apiKey: 'sk-ant-test',
        base64Image: 'AAAA',
        mediaType: 'image/jpeg',
        system: 'sys',
        prompt: 'p',
        schema: const {'type': 'object'},
      );
      expect(out['diagnosis'], 'Фитофтороз');
      expect(captured.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(captured.headers['x-api-key'], 'sk-ant-test');
      expect(captured.headers['anthropic-version'], ClaudeApiClient.apiVersion);
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['model'], 'claude-opus-5-5');
      expect(body['output_config']['format']['type'], 'json_schema');
      expect(body['messages'][0]['content'][0]['type'], 'image');
      expect(body.containsKey('temperature'), isFalse);
    });

    test('maps HTTP errors', () async {
      final client = ClaudeApiClient(
        httpClient: MockClient((_) async => http.Response(
            jsonEncode({
              'error': {'type': 'authentication_error', 'message': 'invalid x-api-key'}
            }),
            401)),
      );
      expect(
        () => client.analyzeImage(
            apiKey: 'k', base64Image: 'A', mediaType: 'image/jpeg',
            system: 's', prompt: 'p', schema: const {}),
        throwsA(isA<ClaudeApiException>()
            .having((e) => e.statusCode, 'status', 401)
            .having((e) => e.retryable, 'retryable', false)),
      );
    });

    test('rate limit is retryable, refusal is reported', () async {
      final c429 = ClaudeApiClient(
          httpClient: MockClient((_) async => http.Response('{}', 429)));
      expect(
        () => c429.analyzeImage(
            apiKey: 'k', base64Image: 'A', mediaType: 'image/jpeg',
            system: 's', prompt: 'p', schema: const {}),
        throwsA(isA<ClaudeApiException>().having((e) => e.retryable, 'r', true)),
      );
      final refusal = ClaudeApiClient(
          httpClient: MockClient((_) async => http.Response(
              jsonEncode({'stop_reason': 'refusal', 'content': []}), 200)));
      expect(
        () => refusal.analyzeImage(
            apiKey: 'k', base64Image: 'A', mediaType: 'image/jpeg',
            system: 's', prompt: 'p', schema: const {}),
        throwsA(isA<ClaudeApiException>().having((e) => e.message, 'm', 'refusal')),
      );
    });
  });

  test('AiService without key returns offline advice and makes no request', () async {
    var calls = 0;
    final ai = AiService(
        client: ClaudeApiClient(httpClient: MockClient((_) async {
      calls++;
      return http.Response('{}', 500);
    })));
    final tmp = File('${Directory.systemTemp.path}/agro_test.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    final s = await ai.analyze(
        image: tmp, savedImagePath: tmp.path, apiKey: '', lang: 'tg', knowledge: kb);
    expect(s.source, ScanSource.offline);
    expect(calls, 0);
  });
}
