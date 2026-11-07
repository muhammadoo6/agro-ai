import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../services/error_log.dart';
import '../../shared/widgets/common.dart';

/// «Маълумот ва бехатарӣ»: база, автокопияҳо, журнали хатоҳо.
class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  List<File> _backups = const [];
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final list = await AppScope.of(context).backup.listAutoBackups();
      if (mounted) setState(() => _backups = list);
    } catch (_) {}
  }

  Future<void> _backupNow() async {
    final s = AppScope.of(context);
    final l = context.l;
    setState(() => _busy = true);
    try {
      final f = await s.backup.autoBackupIfDue(s.farm);
      if (mounted) showSnack(context, l.t(f == null ? 'backup_today_exists' : 'backup_done'));
    } catch (e, st) {
      ErrorLog.instance.record(e, st, context: 'manual-backup');
      if (mounted) showSnack(context, '${l.t('error')}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      await _reload();
    }
  }

  Future<void> _restore(File f) async {
    final s = AppScope.of(context);
    final l = context.l;
    if (!await confirmDialog(context, l.t('backup_import_confirm'))) return;
    try {
      await s.backup.restoreFromFile(s.farm, f);
      await s.notifications.cancelAll();
      if (mounted) showSnack(context, l.t('restore_done'));
    } on FormatException {
      if (mounted) showSnack(context, l.t('backup_invalid'));
    } catch (e, st) {
      ErrorLog.instance.record(e, st, context: 'restore');
      if (mounted) showSnack(context, '${l.t('error')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = context.l;
    final farm = s.farm;
    final errors = ErrorLog.instance.recent;
    return Scaffold(
      appBar: AppBar(title: Text(l.t('data_safety'))),
      body: ListenableBuilder(
        listenable: farm,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      farm.lastSaveError == null ? Icons.verified_outlined : Icons.error_outline,
                      color: farm.lastSaveError == null ? Colors.green : Colors.red,
                    ),
                    title: Text(l.t(farm.lastSaveError == null ? 'db_ok' : 'db_error')),
                    subtitle: farm.lastSaveError == null ? null : Text('${farm.lastSaveError}'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: Text(l.f('db_records', [farm.totalRecords])),
                    subtitle: Text(farm.storageDescription,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(l.t('db_private')),
                  ),
                ],
              ),
            ),
            SectionHeader(
              l.t('auto_backups'),
              trailing: TextButton.icon(
                onPressed: _busy ? null : _backupNow,
                icon: const Icon(Icons.save_outlined),
                label: Text(l.t('backup_now')),
              ),
            ),
            Text(l.f('auto_backups_desc', [7]), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (_backups.isEmpty)
              Card(child: ListTile(title: Text(l.t('no_backups'))))
            else
              Card(
                child: Column(
                  children: [
                    for (final f in _backups)
                      ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(formatDateTime(f.lastModifiedSync())),
                        subtitle: Text('${(f.lengthSync() / 1024).toStringAsFixed(1)} KB'),
                        trailing: TextButton(
                          onPressed: () => _restore(f),
                          child: Text(l.t('backup_import')),
                        ),
                      ),
                  ],
                ),
              ),
            SectionHeader(l.t('error_log')),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(errors.isEmpty ? Icons.check_circle_outline : Icons.bug_report_outlined,
                        color: errors.isEmpty ? Colors.green : Colors.orange),
                    title: Text(errors.isEmpty
                        ? l.t('no_errors')
                        : l.f('errors_count', [errors.length])),
                  ),
                  if (ErrorLog.instance.file != null)
                    ListTile(
                      leading: const Icon(Icons.share_outlined),
                      title: Text(l.t('send_log')),
                      onTap: () async {
                        final f = ErrorLog.instance.file!;
                        if (!await f.exists()) {
                          if (context.mounted) showSnack(context, l.t('no_errors'));
                          return;
                        }
                        await SharePlus.instance
                            .share(ShareParams(files: [XFile(f.path, mimeType: 'text/plain')]));
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
