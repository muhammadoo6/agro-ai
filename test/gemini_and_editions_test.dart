import 'package:agro_ai/core/validation/validators.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agro_ai/app.dart';
import 'package:agro_ai/core/app_config.dart';
import 'package:agro_ai/data/local/local_store.dart';
import 'package:agro_ai/data/remote/claude_api_client.dart';
import 'package:agro_ai/data/remote/gemini_api_client.dart';
import 'package:agro_ai/data/repositories/settings_repository.dart';
import 'package:agro_ai/main.dart';
import 'package:agro_ai/services/notification_service.dart';
import 'package:agro_ai/services/offline/plant_classifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Fake implements PlantClassifier {
  @override
  List<String> get labels => const ['Potato___Late_blight', 'Potato___healthy'];
  @override
  Future<ClassifyResult> classify(Uint8List imageBytes) async =>
      const ClassifyResult([0.9, 0.1]);
}

void main() {
  group('GeminiApiClient', () {
    test('request shape and JSON parsing', () async {
      late http.Request req;
      final c = GeminiApiClient(httpClient: MockClient((r) async {
        req = r;
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'candidates': [
              {
                'finishReason': 'STOP',
                'content': {
                  'parts': [
                    {'text': '{"diagnosis":"Фитофтороз","is_healthy":false}'},
                  ],
                },
              },
            ],
          })),
          200,
        );
      }));
      final out = await c.analyzeImage(
        apiKey: 'AIzaTEST',
        base64Image: 'AAAA',
        mediaType: 'image/jpeg',
        system: 'sys',
        prompt: 'p',
        schema: const {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'tags': {'type': 'array', 'items': {'type': 'string'}},
          },
        },
      );
      expect(out['diagnosis'], 'Фитофтороз');
      expect(req.url.path, '/v1beta/models/${GeminiApiClient.defaultModel}:generateContent');
      expect(req.headers['x-goog-api-key'], 'AIzaTEST');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final schema = body['generationConfig']['responseSchema'] as Map<String, dynamic>;
      expect(schema['type'], 'OBJECT');
      expect(schema.containsKey('additionalProperties'), isFalse);
      expect(schema['properties']['tags']['items']['type'], 'STRING');
      expect(body['contents'][0]['parts'][0]['inline_data']['mime_type'], 'image/jpeg');
    });

    test('quota error is retryable, safety block is refusal', () async {
      final q = GeminiApiClient(
          httpClient: MockClient((_) async => http.Response(
              '{"error":{"status":"RESOURCE_EXHAUSTED","message":"quota"}}', 429)));
      expect(
        () => q.analyzeImage(apiKey: 'k', base64Image: 'A', mediaType: 'image/jpeg',
            system: 's', prompt: 'p', schema: const {}),
        throwsA(isA<ClaudeApiException>().having((e) => e.retryable, 'r', true)),
      );
      final blocked = GeminiApiClient(
          httpClient: MockClient((_) async => http.Response(
              '{"promptFeedback":{"blockReason":"SAFETY"}}', 200)));
      expect(
        () => blocked.analyzeImage(apiKey: 'k', base64Image: 'A', mediaType: 'image/jpeg',
            system: 's', prompt: 'p', schema: const {}),
        throwsA(isA<ClaudeApiException>().having((e) => e.message, 'm', 'refusal')),
      );
    });
  });

  group('GeminiApiClient model discovery', () {
    http.Response ok(String text) => http.Response.bytes(
        utf8.encode(jsonEncode({
          'candidates': [
            {
              'finishReason': 'STOP',
              'content': {
                'parts': [
                  {'text': text},
                ],
              },
            },
          ],
        })),
        200);

    test('picks models the key can use and skips closed ones', () async {
      final posted = <String>[];
      final c = GeminiApiClient(httpClient: MockClient((r) async {
        if (r.method == 'GET') {
          return http.Response(
              jsonEncode({
                'models': [
                  {'name': 'models/gemini-2.5-pro', 'supportedGenerationMethods': ['generateContent']},
                  {'name': 'models/gemini-2.5-flash', 'supportedGenerationMethods': ['generateContent']},
                  {'name': 'models/gemini-2.5-flash-lite', 'supportedGenerationMethods': ['generateContent']},
                  {'name': 'models/text-embedding-004', 'supportedGenerationMethods': ['embedContent']},
                ],
              }),
              200);
        }
        final model = r.url.pathSegments.last.split(':').first;
        posted.add(model);
        if (model == 'gemini-2.5-flash') {
          return http.Response('{"error":{"status":"RESOURCE_EXHAUSTED","message":"limit 0"}}', 429);
        }
        return ok('{"diagnosis":"ok"}');
      }));
      final out = await c.analyzeImage(apiKey: 'AQ.${'x' * 40}', base64Image: 'A',
          mediaType: 'image/jpeg', system: 's', prompt: 'p', schema: const {});
      expect(out['diagnosis'], 'ok');
      expect(posted, ['gemini-2.5-flash', 'gemini-2.5-flash-lite']);
      // Рабочая модель запоминается.
      posted.clear();
      await c.analyzeImage(apiKey: 'AQ.${'x' * 40}', base64Image: 'A',
          mediaType: 'image/jpeg', system: 's', prompt: 'p', schema: const {});
      expect(posted, ['gemini-2.5-flash-lite']);
    });

    test('invalid key stops at once with bad_key', () async {
      var calls = 0;
      final c = GeminiApiClient(httpClient: MockClient((r) async {
        calls++;
        return http.Response(
            '{"error":{"status":"INVALID_ARGUMENT","message":"API key not valid. Please pass a valid API key."}}',
            400);
      }));
      await expectLater(
        c.checkKey('AIza${'x' * 35}'),
        throwsA(isA<ClaudeApiException>().having((e) => e.message, 'm', 'bad_key')),
      );
      expect(calls, 1);
    });

    test('checkKey falls back to known names when list fails', () async {
      final c = GeminiApiClient(httpClient: MockClient((r) async {
        if (r.method == 'GET') return http.Response('oops', 503);
        final model = r.url.pathSegments.last.split(':').first;
        if (model == GeminiApiClient.defaultModel) {
          return http.Response('{"error":{"status":"NOT_FOUND","message":"no"}}', 404);
        }
        return ok('hi');
      }));
      expect(await c.checkKey('AIza${'x' * 35}'), GeminiApiClient.fallbackModel);
    });

    test('schema rejected -> retries with plain JSON and strips code fence', () async {
      final bodies = <Map<String, dynamic>>[];
      final c = GeminiApiClient(httpClient: MockClient((r) async {
        if (r.method == 'GET') return http.Response('{"models":[]}', 200);
        final b = jsonDecode(r.body) as Map<String, dynamic>;
        bodies.add(b);
        if ((b['generationConfig'] as Map).containsKey('responseSchema')) {
          return http.Response('{"error":{"status":"INVALID_ARGUMENT","message":"schema"}}', 400);
        }
        return ok('```json\n{"diagnosis":"x"}\n```');
      }));
      final out = await c.analyzeImage(apiKey: 'AIza${'x' * 35}', base64Image: 'A',
          mediaType: 'image/jpeg', system: 's', prompt: 'p',
          schema: const {'type': 'object', 'properties': {'diagnosis': {'type': 'string'}}});
      expect(out['diagnosis'], 'x');
      expect(bodies.length, 2);
    });
  });

  test('settings: provider and per-provider keys persist', () async {
    final store = MemoryStore();
    final s = SettingsRepository(store);
    await s.update(const AppSettings(geminiKey: 'AIzaX', apiKey: 'sk-ant-Y'));
    expect(s.value.aiProvider, AiProvider.gemini);
    expect(s.value.activeKey, 'AIzaX');
    final again = SettingsRepository(store);
    await again.load();
    expect(again.value.copyWith(aiProvider: AiProvider.claude).activeKey, 'sk-ant-Y');
  });

  test('AppConfig from flavor', () {
    expect(AppConfig.fromFlavor('offline').isOffline, isTrue);
    expect(AppConfig.fromFlavor('online').isOffline, isFalse);
  });

  testWidgets('offline edition shows own model info, no key settings', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final services = await tester.runAsync(() => bootstrap(
          store: MemoryStore(),
          notifications: NoopNotificationService(),
          loadModel: false,
          config: const AppConfig(AppEdition.offline),
          classifier: _Fake(),
        ));
    await tester.runAsync(() => services!.settings
        .update(services.settings.value.copyWith(onboarded: true)));
    await tester.pumpWidget(AgroApp(services: services!));
    await tester.pumpAndSettle();
    expect(services.offline, isNotNull);

    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Скан')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Модели худии барнома'), findsOneWidget);
    expect(find.textContaining('Модел 1 бемориро медонад'), findsOneWidget);

    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Асосӣ')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Модели офлайн'), findsOneWidget);
    expect(find.text('Калиди Claude API'), findsNothing);
    expect(find.text('Калиди Gemini API'), findsNothing);
  });

  testWidgets('online edition offers Gemini (free) by default', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final services = await tester.runAsync(() => bootstrap(
          store: MemoryStore(),
          notifications: NoopNotificationService(),
          loadModel: false,
          config: const AppConfig(AppEdition.online),
        ));
    await tester.runAsync(() => services!.settings
        .update(services.settings.value.copyWith(onboarded: true)));
    await tester.pumpWidget(AgroApp(services: services!));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Gemini (ройгон)'), findsOneWidget);
    expect(find.text('Калиди Gemini API'), findsOneWidget);
    expect(services.offline, isNull);
  });

  test('geminiKey format: old AIza and new AQ. keys accepted', () {
    expect(Validators.geminiKey('AIza${'x' * 35}'), isNull);
    expect(Validators.geminiKey('AQ.${'x' * 50}'), isNull);
    expect(Validators.geminiKey('short'), 'err_gemini_key');
    expect(Validators.geminiKey('AQ.abc def${'x' * 30}'), 'err_gemini_key');
  });
}
