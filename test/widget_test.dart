import 'package:agro_ai/app.dart';
import 'package:agro_ai/data/local/local_store.dart';
import 'package:agro_ai/main.dart';
import 'package:agro_ai/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final services = await tester.runAsync(() => bootstrap(
          store: MemoryStore(),
          notifications: NoopNotificationService(),
        ));
    await tester.pumpWidget(AgroApp(services: services!));
    await tester.pumpAndSettle();
  }

  testWidgets('app starts on Tajik home screen', (tester) async {
    await pumpApp(tester);
    expect(find.text('Хуш омадед, деҳқон!'), findsOneWidget);
    expect(find.text('Қитъаҳо'), findsWidgets);
  });

  testWidgets('bottom navigation opens every tab', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Скан'));
    await tester.pumpAndSettle();
    expect(find.text('Скани растанӣ'), findsWidgets);

    await tester.tap(find.text('Дафтар'));
    await tester.pumpAndSettle();
    expect(find.text('Дафтари хоҷагӣ'), findsOneWidget);

    await tester.tap(find.text('Донишнома').last);
    await tester.pumpAndSettle();
    expect(find.text('Пахта'), findsOneWidget);
  });

  testWidgets('add plot: validation then save', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Қитъаҳо').last);
    await tester.pumpAndSettle();
    expect(find.text('Ҳоло қитъа нест'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text('Ин майдон ҳатмист'), findsWidgets);

    await tester.enterText(find.byKey(const Key('plot_name')), 'Замини поён');
    await tester.enterText(find.byKey(const Key('plot_area')), '1,5');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    expect(find.text('Замини поён'), findsOneWidget);
    expect(find.textContaining('1,5 га'), findsOneWidget);
  });

  testWidgets('language switch to Russian', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();
    expect(find.text('Добро пожаловать, фермер!'), findsOneWidget);
  });
}
