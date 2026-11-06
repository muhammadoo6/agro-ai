import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/labels.dart';
import '../../core/navigation/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/crop_cycle.dart';
import '../../shared/widgets/common.dart';

class PlotDetailScreen extends StatelessWidget {
  const PlotDetailScreen({super.key, required this.plotId});

  final String plotId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = context.l;
    return ListenableBuilder(
      listenable: s.farm,
      builder: (context, _) {
        final farm = s.farm;
        final plot = farm.plotById(plotId);
        if (plot == null) {
          // Қитъа нест карда шуд.
          return Scaffold(appBar: AppBar());
        }
        final cycles = farm.cyclesForPlot(plotId);
        final irrigations = farm.irrigationsForPlot(plotId);
        final harvests = farm.harvestsForPlot(plotId);
        final finance = farm.summary(plotId: plotId);
        final totalKg = farm.totalHarvestKg(plotId: plotId);

        return Scaffold(
          appBar: AppBar(
            title: Text(plot.name),
            actions: [
              IconButton(
                tooltip: l.t('edit'),
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => AppRouter.plotForm(context, plot: plot),
              ),
              IconButton(
                tooltip: l.t('delete'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await confirmDialog(
                      context, l.t('confirm_delete_plot'),
                      confirmLabel: l.t('delete'));
                  if (!ok || !context.mounted) return;
                  final removed = await farm.deletePlot(plotId);
                  for (final i in removed) {
                    await s.notifications.cancel(i.notificationId);
                  }
                  if (context.mounted) {
                    showSnack(context, l.t('deleted'));
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.straighten,
                      label: l.t('stat_area'),
                      value: '${formatNumber(plot.areaHa)} ${l.t('ha')}',
                      color: AppColors.soil,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.inventory_2_outlined,
                      label: l.t('total_harvest'),
                      value: '${formatNumber(totalKg)} ${l.t('kg')}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.account_balance_wallet_outlined,
                      label: l.t('balance'),
                      value: formatMoney(finance.balance),
                      color: finance.balance >= 0
                          ? AppColors.income
                          : AppColors.expense,
                    ),
                  ),
                ],
              ),
              if (plot.areaHa > 0 && totalKg > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(l.f('yield_per_ha',
                      [formatNumber(totalKg / plot.areaHa)])),
                ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.terrain_outlined),
                      title: Text(l.soil(plot.soilType)),
                      subtitle: Text(l.t('plot_soil')),
                    ),
                    if (plot.location?.isNotEmpty == true)
                      ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(plot.location!),
                      ),
                    if (plot.notes?.isNotEmpty == true)
                      ListTile(
                        leading: const Icon(Icons.notes),
                        title: Text(plot.notes!),
                      ),
                  ],
                ),
              ),
              SectionHeader(
                l.t('crop_cycles'),
                trailing: TextButton.icon(
                  onPressed: () => AppRouter.cycleForm(context, plotId: plotId),
                  icon: const Icon(Icons.add),
                  label: Text(l.t('add')),
                ),
              ),
              if (cycles.isEmpty)
                Card(child: ListTile(title: Text(l.t('no_cycles'))))
              else
                for (final c in cycles) _CycleCard(cycle: c),
              SectionHeader(
                l.t('irrigation_history'),
                trailing: TextButton.icon(
                  onPressed: () =>
                      AppRouter.irrigationForm(context, plotId: plotId),
                  icon: const Icon(Icons.add),
                  label: Text(l.t('add')),
                ),
              ),
              if (irrigations.isEmpty)
                Card(child: ListTile(title: Text(l.t('no_irrigation'))))
              else
                Card(
                  child: Column(
                    children: [
                      for (final i in irrigations.take(5))
                        ListTile(
                          leading: const Icon(Icons.water_drop, color: AppColors.water),
                          title: Text(
                              '${formatDate(i.date)} · ${l.method(i.method)}'),
                          subtitle: Text([
                            '${i.durationMinutes} ${l.t('min')}',
                            if (i.volumeM3 != null) '${formatNumber(i.volumeM3!)} м³',
                          ].join(' · ')),
                          onTap: () =>
                              AppRouter.irrigationForm(context, irrigation: i),
                        ),
                    ],
                  ),
                ),
              SectionHeader(
                l.t('tab_harvest'),
                trailing: TextButton.icon(
                  onPressed: () => AppRouter.harvestForm(context, plotId: plotId),
                  icon: const Icon(Icons.add),
                  label: Text(l.t('add')),
                ),
              ),
              if (harvests.isEmpty)
                Card(child: ListTile(title: Text(l.t('no_harvests'))))
              else
                Card(
                  child: Column(
                    children: [
                      for (final h in harvests)
                        ListTile(
                          leading: const Icon(Icons.agriculture),
                          title: Text(
                              '${h.cropName} · ${formatNumber(h.quantityKg)} ${l.t('kg')}'),
                          subtitle: Text(formatDate(h.date)),
                          trailing: h.totalValue > 0
                              ? Text(formatMoney(h.totalValue))
                              : null,
                          onTap: () => AppRouter.harvestForm(context, harvest: h),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CycleCard extends StatelessWidget {
  const _CycleCard({required this.cycle});

  final CropCycle cycle;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = context.l;
    final guide = s.knowledge.findByName(cycle.cropName);
    final progress = cycle.progress();
    final color = switch (cycle.status) {
      CycleStatus.planned => Colors.blueGrey,
      CycleStatus.growing => AppColors.primary,
      CycleStatus.harvested => AppColors.secondary,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(guide?.icon ?? '🌱', style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cycle.variety == null
                              ? cycle.cropName
                              : '${cycle.cropName} («${cycle.variety}»)',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '${l.t('planting_date')}: ${formatDate(cycle.plantingDate)}'
                          '${cycle.expectedHarvestDate == null ? '' : '\n${l.t('expected_harvest')}: ${formatDate(cycle.expectedHarvestDate!)}'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Pill(l.cycleStatus(cycle.status), color: color),
                ],
              ),
              if (cycle.isActive && progress != null) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                    value: progress, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 4),
                Text(l.f('day_n', [cycle.daysSincePlanting()]),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: [
                  if (cycle.status == CycleStatus.growing)
                    TextButton.icon(
                      onPressed: () => s.farm.saveCycle(
                          cycle.copyWith(status: CycleStatus.harvested)),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(l.t('status_harvested')),
                    ),
                  if (guide != null)
                    TextButton.icon(
                      onPressed: () => AppRouter.cropGuide(context, guide),
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: Text(l.t('knowledge')),
                    ),
                  TextButton.icon(
                    onPressed: () => AppRouter.cycleForm(context,
                        plotId: cycle.plotId, cycle: cycle),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(l.t('edit')),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      if (await confirmDialog(context, l.t('confirm_delete'),
                          confirmLabel: l.t('delete'))) {
                        await s.farm.deleteCycle(cycle.id);
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(l.t('delete')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
