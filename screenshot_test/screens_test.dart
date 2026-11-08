// Автоматические скриншоты экранов (для проверки интерфейса и презентации).
// Запуск: flutter test --update-goldens screenshot_test/
// Картинки: screenshot_test/screens/<lang>_<name>.png
import 'dart:io';

import 'package:agro_ai/app.dart';
import 'package:agro_ai/core/app_config.dart';
import 'package:agro_ai/core/app_scope.dart';
import 'package:agro_ai/data/local/local_store.dart';
import 'package:agro_ai/main.dart';
import 'package:agro_ai/services/demo_data.dart';
import 'package:agro_ai/services/notification_service.dart';
import 'package:agro_ai/services/offline/plant_classifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake implements PlantClassifier {
  _Fake(this.labels);
  @override
  final List<String> labels;
  @override
  Future<ClassifyResult> classify(Uint8List imageBytes) async =>
      ClassifyResult([for (final l in labels) l == 'Potato___Late_blight' ? 0.91 : 0.09 / (labels.length - 1)]);
}

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  final roboto = FontLoader('Roboto');
  for (final f in dir.listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    if (name.startsWith('Roboto-') && name.endsWith('.ttf') && !name.contains('Condensed')) {
      roboto.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
  }
  await roboto.load();
  final icons = File('${dir.path}/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await l.load();
  }
}

Finder _nav(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  setUpAll(_loadFonts);

  for (final lang in ['tg', 'ru']) {
    final t = lang == 'tg'
        ? (plots: 'Қитъаҳо', scan: 'Скан', diary: 'Дафтар', kb: 'Донишнома', home: 'Асосӣ')
        : (plots: 'Участки', scan: 'Скан', diary: 'Дневник', kb: 'Справочник', home: 'Главная');

    testWidgets('screens $lang', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      Future<void> back() async {
        tester.state<NavigatorState>(find.byType(Navigator).last).pop();
        await tester.pumpAndSettle();
      }

      Future<void> shot(String name) async {
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/${lang}_$name.png'));
      }

      final labels = ['Potato___Late_blight', 'Potato___Early_blight', 'Potato___healthy',
        'Tomato___Late_blight', 'Other___not_leaf'];
      late AppServices s;
      await tester.runAsync(() async {
        s = await bootstrap(
          store: MemoryStore(),
          notifications: NoopNotificationService(),
          config: const AppConfig(AppEdition.offline),
          classifier: _Fake(labels),
          loadModel: false,
        );
        await s.settings.update(s.settings.value.copyWith(languageCode: lang));
      });

      // 1. Приветствие
      await tester.pumpWidget(AgroApp(services: s));
      await shot('01_onboarding');

      // 2. Главная с демо-хозяйством
      await tester.runAsync(() async {
        await s.settings.update(s.settings.value.copyWith(onboarded: true));
        await s.farm.replaceAll(buildDemoFarm());
        // скан для экрана результата
        final scan = s.offline!.interpret(
            probs: [0.91, 0.03, 0.02, 0.02, 0.02], imagePath: '/none.jpg', lang: lang);
        await s.farm.saveScan(scan);
      });
      await tester.pumpAndSettle();
      await shot('02_home');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await shot('03_home_charts');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await shot('04_home_bottom');

      // 3. Участки и карточка участка
      await tester.tap(_nav(t.plots));
      await shot('05_plots');
      await tester.tap(find.byType(InkWell).first);
      await shot('06_plot_detail');
      await back();

      // 4. Скан и результат
      await tester.tap(_nav(t.scan));
      await shot('07_scan');
      await tester.tap(find.byType(ListTile).last);
      await shot('08_scan_result');
      await back();

      // 5. Дневник: итоги
      await tester.tap(_nav(t.diary));
      await shot('09_diary');
      await tester.tap(find.byType(Tab).at(2));
      await shot('10_diary_summary');

      // 6. Справочник
      await tester.tap(_nav(t.kb));
      await shot('11_knowledge');
      await tester.tap(find.byType(ListTile).first);
      await shot('12_crop_guide');
      await back();

      // 7. Настройки и данные
      await tester.tap(_nav(t.home));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await shot('13_settings');
    });
  }
}
