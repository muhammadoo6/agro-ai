import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../farm_diary/farm_diary_screen.dart';
import '../knowledge/knowledge_screen.dart';
import '../plant_scan/plant_scan_screen.dart';
import '../plots/plots_screen.dart';
import 'home_screen.dart';

/// Пайвастаи асосӣ бо панели поёнии навигатсия.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();

  static MainShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>();
}

class MainShellState extends State<MainShell> {
  int _index = 0;

  static const tabHome = 0;
  static const tabPlots = 1;
  static const tabScan = 2;
  static const tabDiary = 3;
  static const tabKnowledge = 4;

  void goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return PopScope(
      canPop: _index == tabHome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goTo(tabHome);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [
            HomeScreen(),
            PlotsScreen(),
            PlantScanScreen(),
            FarmDiaryScreen(),
            KnowledgeScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: goTo,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: l.t('nav_home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.grid_view_outlined),
              selectedIcon: const Icon(Icons.grid_view),
              label: l.t('nav_plots'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.document_scanner_outlined),
              selectedIcon: const Icon(Icons.document_scanner),
              label: l.t('nav_scan'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book),
              label: l.t('nav_diary'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.local_library_outlined),
              selectedIcon: const Icon(Icons.local_library),
              label: l.t('nav_knowledge'),
            ),
          ],
        ),
      ),
    );
  }
}
