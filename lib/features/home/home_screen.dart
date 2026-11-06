import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/labels.dart';
import '../../core/navigation/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction.dart';
import '../../shared/widgets/common.dart';
import 'main_shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = context.l;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('app_name')),
        actions: [
          IconButton(
            tooltip: l.t('settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => AppRouter.settings(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: s.farm,
        builder: (context, _) {
          final farm = s.farm;
          final now = DateTime.now();
          final season = farm.summary(from: DateTime(now.year, 1, 1));
          final upcoming = farm.upcomingIrrigations().take(4).toList();
          final lastScan = farm.scansSorted.isEmpty ? null : farm.scansSorted.first;
          final shell = MainShell.of(context);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Text(l.t('home_greeting'),
                  style: Theme.of(context).textTheme.headlineSmall),
              Text(l.t('home_subtitle'),
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 112,
                ),
                children: [
                  StatTile(
                    icon: Icons.grid_view,
                    label: l.t('stat_plots'),
                    value: '${farm.plots.length}',
                  ),
                  StatTile(
                    icon: Icons.straighten,
                    label: l.t('stat_area'),
                    value: '${formatNumber(farm.totalAreaHa)} ${l.t('ha')}',
                    color: AppColors.soil,
                  ),
                  StatTile(
                    icon: Icons.eco_outlined,
                    label: l.t('stat_active_crops'),
                    value: '${farm.activeCycles.length}',
                  ),
                  StatTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: '${l.t('stat_balance')} · ${now.year}',
                    value: formatMoney(season.balance),
                    color: season.balance >= 0 ? AppColors.income : AppColors.expense,
                  ),
                ],
              ),
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
                    onTap: () => AppRouter.transactionForm(context,
                        type: TransactionType.expense),
                  ),
                ],
              ),
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
                          leading: const Icon(Icons.water_drop, color: AppColors.water),
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
                            ? Image.file(File(lastScan.imagePath), fit: BoxFit.cover)
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
          );
        },
      ),
    );
  }
}
