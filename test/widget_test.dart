import 'package:agro_ai/app.dart';
import 'package:agro_ai/core/app_scope.dart';
import 'package:agro_ai/data/local/local_store.dart';
import 'package:agro_ai/main.dart';
import 'package:agro_ai/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder navItem(String label) => find.descendant(
    of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  Future<AppServices> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final services = await tester.runAsync(() => bootstrap(
          store: MemoryStore(),
          notifications: NoopNotificationService(),
          loadModel: false,
        ));
    await tester.runAsync(() => services!.settings
        .update(services.settings.value.copyWith(onboarded: true)));
    await tester.pumpWidget(AgroApp(services: services!));
    await tester.pumpAndSettle();
    return services;
  }

  testWidgets('app starts on Tajik home screen', (tester) async {
    await pumpApp(tester);
    expect(find.textContaining('Хоҷагии шумо имрӯз'), findsOneWidget);
    expect(find.text('Хоҷагии намунавӣ'), findsOneWidget);
    expect(navItem('Қитъаҳо'), findsOneWidget);
  });

  testWidgets('bottom navigation opens every tab', (tester) async {
    await pumpApp(tester);
    await tester.tap(navItem('Скан'));
    await tester.pumpAndSettle();
    expect(find.text('Скани растанӣ'), findsWidgets);

    await tester.tap(navItem('Дафтар'));
    await tester.pumpAndSettle();
    expect(find.text('Дафтари хоҷагӣ'), findsOneWidget);

    await tester.tap(navItem('Донишнома'));
    await tester.pumpAndSettle();
    expect(find.text('Пахта'), findsOneWidget);
  });

  testWidgets('add plot: validation then save', (tester) async {
    final services = await pumpApp(tester);
    await tester.tap(navItem('Қитъаҳо'));
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

    expect(services.farm.plots.single.areaHa, 1.5);
    expect(find.text('Замини поён'), findsOneWidget);
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .toList();
    expect(texts.any((t) => t.contains('1,5 га')), isTrue,
        reason: 'visible texts: $texts');
  });

  testWidgets('language switch to Russian', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ваше хозяйство сегодня'), findsOneWidget);
  });
}
