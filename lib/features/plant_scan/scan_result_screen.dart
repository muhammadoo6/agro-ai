import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/labels.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/plant_scan.dart';
import '../../shared/widgets/charts.dart';
import '../../shared/widgets/common.dart';

class ScanResultScreen extends StatelessWidget {
  const ScanResultScreen({super.key, required this.scanId, required this.initial});

  final String scanId;
  final PlantScan initial;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = context.l;
    final scan = s.farm.scans.where((e) => e.id == scanId).firstOrNull ?? initial;
    final offline = scan.source == ScanSource.offline;
    final statusColor = offline
        ? Colors.blueGrey
        : scan.isHealthy
            ? AppColors.primary
            : AppColors.warning;
    final file = File(scan.imagePath);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('diagnosis')),
        actions: [
          IconButton(
            tooltip: l.t('delete'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (!await confirmDialog(context, l.t('confirm_delete'),
                  confirmLabel: l.t('delete'))) {
                return;
              }
              await s.farm.deleteScan(scan.id);
              try {
                if (await file.exists()) await file.delete();
              } catch (_) {}
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (file.existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.file(file, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill(
                  l.t(switch (scan.source) {
                    ScanSource.ai => 'source_ai',
                    ScanSource.model => 'source_model',
                    ScanSource.offline => 'source_offline',
                  }),
                  color: Colors.blueGrey),
              if (!offline && !(scan.source == ScanSource.model && scan.confidence < 0.55))
                Pill(l.t(scan.isHealthy ? 'healthy' : 'unhealthy'), color: statusColor),
              if (!offline && scan.severity != Severity.none)
                Pill('${l.t('severity')}: ${l.severity(scan.severity)}',
                    color: scan.severity == Severity.high
                        ? AppColors.expense
                        : AppColors.warning),
              if (scan.cropName?.isNotEmpty == true) Pill('🌱 ${scan.cropName}'),
            ],
          ),
          const SizedBox(height: 12),
          Text(scan.diagnosis, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(formatDateTime(scan.date), style: Theme.of(context).textTheme.bodySmall),
          if (!offline && scan.confidence > 0) ...[
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  ConfidenceGauge(value: scan.confidence, color: statusColor, size: 150),
                  Text(l.t('confidence'), style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
          ],
          if (offline) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: Text(l.t('offline_note')),
              ),
            ),
          ],
          _Section(title: l.t('symptoms'), icon: Icons.search, items: scan.symptoms),
          _Section(
              title: l.t('recommendations'),
              icon: Icons.medical_services_outlined,
              items: scan.recommendations),
          _Section(title: l.t('prevention'), icon: Icons.shield_outlined, items: scan.prevention),
          const SizedBox(height: 16),
          Text(
            l.t('ai_disclaimer'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.items});

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final i in items)
                  ListTile(
                    dense: true,
                    leading: Icon(icon, size: 20),
                    title: Text(i),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
