import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/labels.dart';
import '../../core/navigation/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/common.dart';

class IrrigationScreen extends StatelessWidget {
  const IrrigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.t('irrigation'))),
      floatingActionButton: s.farm.plots.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'add_irrigation',
              onPressed: () => AppRouter.irrigationForm(context),
              icon: const Icon(Icons.water_drop),
              label: Text(l.t('new_irrigation')),
            ),
      body: ListenableBuilder(
        listenable: s.farm,
        builder: (context, _) {
          final farm = s.farm;
          if (farm.plots.isEmpty) {
            return EmptyState(
              icon: Icons.landscape_outlined,
              title: l.t('no_plots'),
              message: l.t('no_plots_hint'),
              action: FilledButton.icon(
                onPressed: () => AppRouter.plotForm(context),
                icon: const Icon(Icons.add),
                label: Text(l.t('new_plot')),
              ),
            );
          }
          final upcoming = farm.upcomingIrrigations();
          final history = farm.irrigationsSorted;
          final now = DateTime.now();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              StatTile(
                icon: Icons.water,
                label: l.t('total_water'),
                value: '${formatNumber(farm.totalWaterM3())} м³',
                color: AppColors.water,
              ),
              SectionHeader(l.t('upcoming_irrigation')),
              if (upcoming.isEmpty)
                Card(child: ListTile(title: Text(l.t('no_upcoming_irrigation'))))
              else
                Card(
                  child: Column(
                    children: [
                      for (final i in upcoming)
                        ListTile(
                          leading: Icon(
                            i.remind
                                ? Icons.notifications_active_outlined
                                : Icons.event_outlined,
                            color: AppColors.water,
                          ),
                          title: Text(farm.plotById(i.plotId)?.name ?? ''),
                          subtitle: Text(formatDate(i.nextPlannedDate!)),
                          trailing: Pill(
                            l.relativeDay(i.nextPlannedDate!),
                            color: i.nextPlannedDate!.isBefore(dateOnly(now))
                                ? AppColors.warning
                                : AppColors.water,
                          ),
                          onTap: () => AppRouter.irrigationForm(context,
                              plotId: i.plotId),
                        ),
                    ],
                  ),
                ),
              SectionHeader(l.t('irrigation_history')),
              if (history.isEmpty)
                Card(child: ListTile(title: Text(l.t('no_irrigation'))))
              else
                Card(
                  child: Column(
                    children: [
                      for (final i in history)
                        ListTile(
                          leading: const Icon(Icons.water_drop, color: AppColors.water),
                          title: Text(
                              '${farm.plotById(i.plotId)?.name ?? ''} · ${formatDate(i.date)}'),
                          subtitle: Text([
                            l.method(i.method),
                            '${i.durationMinutes} ${l.t('min')}',
                            if (i.volumeM3 != null)
                              '${formatNumber(i.volumeM3!)} м³',
                          ].join(' · ')),
                          onTap: () =>
                              AppRouter.irrigationForm(context, irrigation: i),
                        ),
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
