import 'package:agro_ai/app.dart';
import 'package:agro_ai/data/local/local_store.dart';
import 'package:agro_ai/main.dart';
import 'package:agro_ai/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Finder navItem(String label) => find.descendant(
    of: find.byType(NavigationBar), matching: find.text(label));

/// Ҷараёни пурра дар дастгоҳ: қитъа → мавсим → обёрӣ → хароҷот → хулоса.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full farmer flow', (tester) async {
    final services = await bootstrap(
      store: MemoryStore(),
      notifications: NoopNotificationService(),
    );
    await tester.pumpWidget(AgroApp(services: services));
    await tester.pumpAndSettle();

    // 1. Қитъа
    await tester.tap(navItem('Қитъаҳо'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('plot_name')), 'Қитъаи 1');
    await tester.enterText(find.byKey(const Key('plot_area')), '2');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();

    // 2. Мавсим
    await tester.tap(find.text('Қитъаи 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Илова').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Пахта'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text('Дар парвариш'), findsOneWidget);
    expect(services.farm.cycles.single.expectedHarvestDate, isNotNull);

    // 3. Обёрӣ
    await tester.scrollUntilVisible(find.text('Илова').at(1), 200);
    await tester.tap(find.text('Илова').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(services.farm.irrigations.length, 1);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 4. Хароҷот
    await tester.tap(navItem('Дафтар'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Хароҷот').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount')), '500');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(services.farm.summary().expense, 500);

    // 5. Асосӣ
    await tester.tap(navItem('Асосӣ'));
    await tester.pumpAndSettle();
    expect(find.text('Қитъаи 1'), findsOneWidget); // обёрии наздик
  });
}
