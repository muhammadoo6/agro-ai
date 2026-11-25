import 'dart:convert';
import 'dart:io';

import 'package:agro_ai/data/local/local_store.dart';
import 'package:agro_ai/data/remote/gemini_api_client.dart';
import 'package:agro_ai/data/repositories/settings_repository.dart';
import 'package:agro_ai/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('analysis without own key goes to our proxy with the device id', () async {
    final seen = <http.Request>[];
    final proxy = GeminiApiClient(
      baseUrl: 'https://proxy.example',
      httpClient: MockClient((r) async {
        seen.add(r);
        if (r.method == 'GET') {
          return http.Response(
              jsonEncode({
                'models': [
                  {'name': 'models/gemini-2.5-flash', 'supportedGenerationMethods': ['generateContent']},
                ],
              }),
              200);
        }
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'candidates': [
                {
                  'finishReason': 'STOP',
                  'content': {
                    'parts': [
                      {'text': '{"crop":"Помидор","diagnosis":"Помидор","is_healthy":true,"confidence":0.9}'},
                    ],
                  },
                },
              ],
            })),
            200);
      }),
    );
    final ai = AiService(proxy: proxy);
    expect(ai.hasProxy, isTrue);

    final dir = await Directory.systemTemp.createTemp('agro');
    final img = File('${dir.path}/a.jpg')..writeAsBytesSync([1, 2, 3]);
    final scan = await ai.analyze(
      image: img,
      savedImagePath: img.path,
      apiKey: 'dev-1234567890',
      lang: 'ru',
      provider: AiProvider.gemini,
      viaProxy: true,
    );
    expect(scan.diagnosis, 'Помидор');
    expect(seen, isNotEmpty);
    for (final r in seen) {
      expect(r.url.host, 'proxy.example');
      expect(r.headers['x-goog-api-key'], 'dev-1234567890');
    }
    await dir.delete(recursive: true);
  });

  test('no proxy configured: hasProxy is false', () {
    expect(AiService(proxyUrl: '').hasProxy, isFalse);
  });

  test('device id is created once and then kept', () async {
    final store = MemoryStore();
    final a = await SettingsRepository(store).deviceId();
    final b = await SettingsRepository(store).deviceId();
    expect(a, b);
    expect(a.length, greaterThanOrEqualTo(8));
  });
}
