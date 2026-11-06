import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../shared/widgets/common.dart';
import 'crop_guide.dart';

class CropGuideScreen extends StatelessWidget {
  const CropGuideScreen({super.key, required this.guide});

  final CropGuide guide;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final theme = Theme.of(context);
    Widget block(String title, IconData icon, String text) => text.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(icon, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(title, style: theme.textTheme.titleSmall),
                    ]),
                    const SizedBox(height: 8),
                    Text(text),
                  ],
                ),
              ),
            ),
          );

    return Scaffold(
      appBar: AppBar(title: Text('${guide.icon} ${guide.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(guide.latin,
              style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Text(guide.summary, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          block(l.t('sowing_time'), Icons.calendar_month_outlined, guide.sowingTime),
          block(l.t('soil'), Icons.terrain_outlined, guide.soil),
          block(l.t('watering'), Icons.water_drop_outlined, guide.watering),
          block(l.t('fertilizing'), Icons.science_outlined, guide.fertilizing),
          if (guide.diseases.isNotEmpty) ...[
            SectionHeader(l.t('diseases')),
            for (final d in guide.diseases)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    leading: const Icon(Icons.coronavirus_outlined),
                    title: Text(d.name),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.t('symptoms'), style: theme.textTheme.labelLarge),
                      Text(d.signs),
                      const SizedBox(height: 8),
                      Text(l.t('recommendations'), style: theme.textTheme.labelLarge),
                      Text(d.treatment),
                    ],
                  ),
                ),
              ),
          ],
          block(l.t('harvesting'), Icons.agriculture_outlined, guide.harvesting),
          if (guide.tips.isNotEmpty) ...[
            SectionHeader(l.t('tips')),
            Card(
              child: Column(
                children: [
                  for (final t in guide.tips)
                    ListTile(
                      leading: const Icon(Icons.lightbulb_outline),
                      title: Text(t),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
