import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_scope.dart';
import 'core/theme/app_theme.dart';
import 'features/home/main_shell.dart';

/// Танзимоти умумии барнома.
class AgroApp extends StatelessWidget {
  const AgroApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: ValueListenableBuilder(
        valueListenable: services.settings,
        builder: (context, settings, _) => MaterialApp(
          // Калиди забон: ҳангоми иваз кардани забон тамоми дарахт аз нав сохта мешавад.
          key: ValueKey(settings.languageCode),
          title: 'Agro AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          // Flutter барои тоҷикӣ тарҷумаи Material надорад, бинобар ин тақвим ва
          // тугмаҳои системавӣ бо русӣ нишон дода мешаванд; матни барнома — бо L10n.
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const MainShell(),
        ),
      ),
    );
  }
}
