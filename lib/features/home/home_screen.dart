import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/labels.dart';
import '../../core/navigation/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction.dart';
import '../../services/demo_data.dart';
import '../../shared/widgets/charts.dart';
import '../../shared/widgets/common.dart';
import 'main_shell.dart';
import 'weather_card.dart';

const _monthShort = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];

const categoryColors = [
  Color(0xFF2E7D32),
  Color(0xFFF9A825),
  Color(0xFF0277BD),
  Color(0xFF6D4C41),
  Color(0xFFC62828),
  Color(0xFF7B1FA2),
  Color(0xFF00897B),
  Color(0xFFEF6C00),
  Color(0xFF546E7A),
];

Future<void> loadDemoFarm(BuildContext context) async {
  final s = AppScope.of(context);
  final l = context.l;
  if (s.farm.totalRecords > 0 &&
      !await confirmDialog(context, l.t('demo_confirm'), confirmLabel: l.t('demo_load'))) {
    return;
  }
  await s.notifications.cancelAll();
  await s.farm.replaceAll(buildDemoFarm());
  if (context.mounted) showSnack(context, l.t('demo_loaded'));
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = context.l;
    return Scaffold(
      body: ListenableBuilder(
        listenable: s.farm,
        builder: (context, _) {
          final farm = s.farm;
          final now = DateTime.now();
          final season = farm.summary(from: DateTime(now.year, 1, 1));
          final upcoming = farm.upcomingIrrigations().take(3).toList();
          final lastScan = farm.scansSorted.isEmpty ? null : farm.scansSorted.first;
          final shell = MainShell.of(context);
          final months = farm.monthlyTotals();
          final cats = season.expenseByCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final hasMoney = months.any((m) => m.income > 0 || m.expense > 0);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 56),
                      child: _Hero(now: now),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 0,
                      child: _StatsRow(
                        plots: farm.plots.length,
                        area: farm.totalAreaHa,
                        crops: farm.activeCycles.length,
                        balance: season.balance,
                      ),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.list(
                  children: [
                    if (farm.plots.isEmpty) _DemoBanner(onTap: () => loadDemoFarm(context)),
                    if (!s.config.isOffline) const WeatherCard(),
                    SectionHeader(l.t('quick_actions')),
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        mainAxisExtent: 124,
                      ),
                      children: [
                        QuickAction(
                          icon: Icons.add_location_alt_outlined,
                          label: l.t('qa_add_plot'),
                          onTap: () => AppRouter.plotForm(context),
                        ),
                        QuickAction(
                          icon: Icons.document_scanner_outlined,
                          label: l.t('qa_scan'),
                          color: const Color(0xFF7B1FA2),
                          onTap: () => shell?.goTo(MainShellState.tabScan),
                        ),
                        QuickAction(
                          icon: Icons.water_drop_outlined,
                          label: l.t('qa_irrigation'),
                          color: AppColors.water,
                          onTap: () => AppRouter.irrigation(context),
                        ),
                        QuickAction(
                          icon: Icons.payments_outlined,
                          label: l.t('qa_expense'),
                          color: AppColors.expense,
                          onTap: () =>
                              AppRouter.transactionForm(context, type: TransactionType.expense),
                        ),
                      ],
                    ),
                    if (hasMoney) ...[
                      SectionHeader(l.t('finance_6m')),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                          child: Column(
                            children: [
                              IncomeExpenseBars(
                                labels: [for (final m in months) _monthShort[m.month.month - 1]],
                                income: [for (final m in months) m.income],
                                expense: [for (final m in months) m.expense],
                                incomeColor: AppColors.income,
                                expenseColor: AppColors.expense,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _Legend(color: AppColors.income, text: l.t('income')),
                                  const SizedBox(width: 16),
                                  _Legend(color: AppColors.expense, text: l.t('expense')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (cats.isNotEmpty) ...[
                      SectionHeader(l.t('by_category')),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              DonutChart(
                                size: 130,
                                thickness: 18,
                                values: [for (final c in cats) c.value],
                                colors: categoryColors,
                                center: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(l.t('expense'),
                                        style: Theme.of(context).textTheme.labelSmall),
                                    FittedBox(
                                      child: Text(
                                        formatNumber(season.expense),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800, fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (var i = 0; i < cats.length && i < 6; i++)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                        child: _Legend(
                                          color: categoryColors[i % categoryColors.length],
                                          text:
                                              '${l.category(cats[i].key)} · ${(cats[i].value / season.expense * 100).round()}%',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    SectionHeader(
                      l.t('upcoming_irrigation'),
                      trailing: TextButton(
                        onPressed: () => AppRouter.irrigation(context),
                        child: Text(l.t('all')),
                      ),
                    ),
                    if (upcoming.isEmpty)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.water_drop_outlined),
                          title: Text(l.t('no_upcoming_irrigation')),
                        ),
                      )
                    else
                      Card(
                        child: Column(
                          children: [
                            for (final i in upcoming)
                              ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0x1A0277BD),
                                  child: Icon(Icons.water_drop, color: AppColors.water),
                                ),
                                title: Text(farm.plotById(i.plotId)?.name ?? ''),
                                subtitle: Text(formatDate(i.nextPlannedDate!)),
                                trailing: Pill(
                                  l.relativeDay(i.nextPlannedDate!),
                                  color: i.nextPlannedDate!.isBefore(dateOnly(now))
                                      ? AppColors.warning
                                      : AppColors.water,
                                ),
                                onTap: () => AppRouter.plotDetail(context, i.plotId),
                              ),
                          ],
                        ),
                      ),
                    if (lastScan != null) ...[
                      SectionHeader(l.t('last_scan')),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: File(lastScan.imagePath).existsSync()
                                  ? Image.file(File(lastScan.imagePath),
                                      fit: BoxFit.cover, cacheWidth: 144)
                                  : const Icon(Icons.image_not_supported_outlined),
                            ),
                          ),
                          title: Text(lastScan.diagnosis,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(formatDateTime(lastScan.date)),
                          onTap: () => AppRouter.scanResult(context, lastScan),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final s = AppScope.of(context);
    final h = now.hour;
    final greet = l.t(h < 11 ? 'greet_morning' : (h < 17 ? 'greet_day' : 'greet_evening'));
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 12, 8, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF66BB6A)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -10,
            bottom: -30,
            child: Icon(Icons.eco, size: 150, color: Color(0x22FFFFFF)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.eco, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Agro AI',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      s.config.isOffline ? 'OFFLINE' : 'ONLINE',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: l.t('settings'),
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                    onPressed: () => AppRouter.settings(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(greet,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${l.t('home_subtitle')} · ${formatDate(now)}',
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.plots,
    required this.area,
    required this.crops,
    required this.balance,
  });

  final int plots;
  final double area;
  final int crops;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    Widget item(IconData icon, String value, String label, Color c) => Expanded(
          child: Column(
            children: [
              Icon(icon, color: c, size: 22),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(value,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: c)),
              ),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        );
    return Material(
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Row(
          children: [
            item(Icons.grid_view, '$plots', l.t('stat_plots'), AppColors.primary),
            item(Icons.straighten, '${formatNumber(area)} ${l.t('ha')}', l.t('stat_area'),
                AppColors.soil),
            item(Icons.eco_outlined, '$crops', l.t('stat_active_crops'), const Color(0xFF558B2F)),
            item(Icons.account_balance_wallet_outlined, formatNumber(balance),
                l.t('stat_balance'), balance >= 0 ? AppColors.income : AppColors.expense),
          ],
        ),
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Card(
      color: const Color(0xFFFFF8E1),
      child: ListTile(
        leading: const Icon(Icons.auto_awesome, color: Color(0xFFF9A825)),
        title: Text(l.t('demo_title')),
        subtitle: Text(l.t('demo_desc')),
        trailing: FilledButton(onPressed: onTap, child: Text(l.t('demo_load'))),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}
