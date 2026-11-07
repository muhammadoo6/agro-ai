import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/navigation/app_router.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/id.dart';
import '../../data/remote/claude_api_client.dart';
import '../../models/plant_scan.dart';
import '../../services/ai_service.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/scanning_preview.dart';

class PlantScanScreen extends StatefulWidget {
  const PlantScanScreen({super.key});

  @override
  State<PlantScanScreen> createState() => _PlantScanScreenState();
}

class _PlantScanScreenState extends State<PlantScanScreen> {
  final _cropHint = TextEditingController();
  String? _plotId;
  bool _busy = false;
  File? _preview;

  @override
  void dispose() {
    _cropHint.dispose();
    super.dispose();
  }

  Future<File> _persistImage(XFile picked) async {
    final dir = await getApplicationDocumentsDirectory();
    final scans = Directory('${dir.path}${Platform.pathSeparator}scans');
    if (!await scans.exists()) await scans.create(recursive: true);
    final ext = picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
    final target = '${scans.path}${Platform.pathSeparator}${newId()}.$ext';
    return File(picked.path).copy(target);
  }

  Future<void> _scan(ImageSource source) async {
    final s = AppScope.of(context);
    final l = context.l;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1568,
      maxHeight: 1568,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final saved = await _persistImage(picked);
      if (mounted) setState(() => _preview = saved);
      final settings = s.settings.value;
      PlantScan result;
      final offline = s.offline;
      if (offline != null && (s.config.isOffline || !settings.hasApiKey)) {
        // Своя модель в телефоне — без интернета.
        result = await offline.diagnose(
          imageBytes: await saved.readAsBytes(),
          imagePath: saved.path,
          lang: settings.languageCode,
          cropHint: _cropHint.text,
          plotId: _plotId,
        );
        await s.farm.saveScan(result);
        if (mounted) await AppRouter.scanResult(context, result);
        return;
      }
      try {
        result = await s.ai.analyze(
          image: saved,
          savedImagePath: saved.path,
          apiKey: settings.activeKey,
          provider: settings.aiProvider,
          lang: settings.languageCode,
          cropHint: _cropHint.text,
          plotId: _plotId,
          knowledge: s.knowledge,
        );
      } on ClaudeApiException catch (e) {
        // Хатои шабака — маслиҳати офлайн, то деҳқон бе ҷавоб намонад.
        if (e.retryable && mounted) {
          showSnack(context, l.f('scan_error', [e.message]));
        }
        if (!e.retryable) rethrow;
        // Нет сети или лимит API — распознаём своей моделью.
        result = offline != null
            ? await offline.diagnose(
                imageBytes: await saved.readAsBytes(),
                imagePath: saved.path,
                lang: settings.languageCode,
                cropHint: _cropHint.text,
                plotId: _plotId,
              )
            : AiService.offlineAdvice(
                imagePath: saved.path,
                lang: settings.languageCode,
                cropHint: _cropHint.text,
                plotId: _plotId,
                knowledge: s.knowledge,
              );
      }
      await s.farm.saveScan(result);
      if (mounted) await AppRouter.scanResult(context, result);
    } catch (e) {
      if (mounted) showSnack(context, l.f('scan_error', ['$e']));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _preview = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.t('plant_scan'))),
      body: ListenableBuilder(
        listenable: Listenable.merge([s.farm, s.settings]),
        builder: (context, _) {
          final scans = s.farm.scansSorted;
          final plots = s.farm.plots;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.eco, size: 48, color: Colors.green),
                      const SizedBox(height: 8),
                      Text(l.t(s.config.isOffline ? 'scan_intro_offline' : 'scan_intro'),
                          textAlign: TextAlign.center),
                      if (s.config.isOffline && s.offline != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          l.f('model_info', [
                            s.offline!.diseaseCount,
                            s.offline!.cropNames(s.settings.value.languageCode).join(', '),
                          ]),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (s.config.isOffline && s.offline == null) ...[
                        const SizedBox(height: 8),
                        Text(
                          l.t('model_missing'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      if (!s.config.isOffline && !s.settings.value.hasApiKey) ...[
                        const SizedBox(height: 8),
                        Text(
                          l.t('offline_note'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _cropHint,
                        decoration: InputDecoration(
                          labelText: l.t('scan_crop_hint'),
                          prefixIcon: const Icon(Icons.eco_outlined),
                        ),
                      ),
                      if (plots.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          initialValue: _plotId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: '${l.t('plot')} (${l.t('optional')})',
                            prefixIcon: const Icon(Icons.landscape_outlined),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                                value: null, child: Text(l.t('no_plot_selected'))),
                            for (final p in plots)
                              DropdownMenuItem<String?>(
                                  value: p.id, child: Text(p.name)),
                          ],
                          onChanged: (v) => setState(() {
                            _plotId = v;
                            final c = v == null ? null : s.farm.activeCycleForPlot(v);
                            if (c != null && _cropHint.text.isEmpty) {
                              _cropHint.text = c.cropName;
                            }
                          }),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_busy && _preview != null)
                        ScanningPreview(file: _preview!, label: l.t('analyzing'))
                      else if (_busy)
                        Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 8),
                            Text(l.t('analyzing')),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _scan(ImageSource.camera),
                                icon: const Icon(Icons.photo_camera),
                                label: Text(l.t('take_photo')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _scan(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library_outlined),
                                label: Text(l.t('from_gallery')),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              SectionHeader(l.t('scan_history')),
              if (scans.isEmpty)
                Card(child: ListTile(title: Text(l.t('no_scans'))))
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final sc in scans)
                        ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: File(sc.imagePath).existsSync()
                                  ? Image.file(File(sc.imagePath),
                                      fit: BoxFit.cover, cacheWidth: 144)
                                  : const Icon(Icons.image_not_supported_outlined),
                            ),
                          ),
                          title: Text(sc.diagnosis,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text([
                            formatDateTime(sc.date),
                            if (sc.cropName?.isNotEmpty == true) sc.cropName!,
                          ].join(' · ')),
                          trailing: Icon(
                            sc.source == ScanSource.offline ||
                                    (sc.source == ScanSource.model && sc.confidence < 0.55)
                                ? Icons.help_outline
                                : sc.isHealthy
                                    ? Icons.check_circle
                                    : Icons.warning_amber_rounded,
                            color: sc.source == ScanSource.offline ||
                                    (sc.source == ScanSource.model && sc.confidence < 0.55)
                                ? null
                                : sc.isHealthy
                                    ? Colors.green
                                    : Colors.orange,
                          ),
                          onTap: () => AppRouter.scanResult(context, sc),
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
