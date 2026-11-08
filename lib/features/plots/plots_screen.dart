import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/labels.dart';
import '../../core/navigation/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/common.dart';

class PlotsScreen extends StatelessWidget {
  const PlotsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.t('plots'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_plot',
        onPressed: () => AppRouter.plotForm(context),
        icon: const Icon(Icons.add),
        label: Text(l.t('new_plot')),
      ),
      body: ListenableBuilder(
        listenable: s.farm,
        builder: (context, _) {
          final plots = s.farm.plots;
          if (plots.isEmpty) {
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
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: plots.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = plots[i];
              final cycle = s.farm.activeCycleForPlot(p.id);
              final progress = cycle?.progress();
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => AppRouter.plotDetail(context, p.id),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0x1A6D4C41),
                              child: Icon(Icons.landscape, color: AppColors.soil),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: Theme.of(context).textTheme.titleMedium),
                                  Text(
                                    [
                                      '${formatNumber(p.areaHa)} ${l.t('ha')}',
                                      l.soil(p.soilType),
                                      if (p.location?.isNotEmpty == true) p.location!,
                                    ].join(' · '),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        if (cycle != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Pill(cycle.cropName),
                              const SizedBox(width: 8),
                              Text(l.f('day_n', [cycle.daysSincePlanting()]),
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                          if (progress != null) ...[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
