import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/validation/validators.dart';
import '../../data/remote/claude_api_client.dart' show ClaudeApiException;
import '../../data/repositories/settings_repository.dart';
import '../../shared/widgets/common.dart';
import '../home/home_screen.dart' show loadDemoFarm;
import 'data_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const appVersion = '2.0.0';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.t('settings'))),
      body: ValueListenableBuilder(
        valueListenable: s.settings,
        builder: (context, settings, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            SectionHeader(l.t('language')),
            Card(
              child: RadioGroup<String>(
                groupValue: settings.languageCode,
                onChanged: (v) {
                  if (v != null) {
                    s.settings.update(settings.copyWith(languageCode: v));
                  }
                },
                child: Column(
                  children: [
                    for (final e in supportedLanguages.entries)
                      RadioListTile<String>(value: e.key, title: Text(e.value)),
                  ],
                ),
              ),
            ),
            SectionHeader(l.t('theme')),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                        value: ThemeMode.system,
                        icon: const Icon(Icons.brightness_auto),
                        label: Text(l.t('theme_system'))),
                    ButtonSegment(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode),
                        label: Text(l.t('theme_light'))),
                    ButtonSegment(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode),
                        label: Text(l.t('theme_dark'))),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (v) =>
                      s.settings.update(settings.copyWith(themeMode: v.first)),
                ),
              ),
            ),
            if (s.config.isOffline) ...[
              SectionHeader(l.t('offline_model_section')),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.memory, color: Colors.green),
                      title: Text(l.t('edition_offline')),
                    ),
                    if (s.offline != null)
                      ListTile(
                        leading: const Icon(Icons.eco_outlined),
                        title: Text(l.f('model_info', [
                          s.offline!.diseaseCount,
                          s.offline!.cropNames(settings.languageCode).join(', '),
                        ])),
                        subtitle: Text(l.t('data_source')),
                      )
                    else
                      ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: Text(l.t('model_missing')),
                      ),
                  ],
                ),
              ),
            ] else ...[
              SectionHeader(l.t('ai_section')),
              Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: SegmentedButton<AiProvider>(
                        segments: [
                          ButtonSegment(
                              value: AiProvider.gemini,
                              label: Text(l.t('provider_gemini'))),
                          ButtonSegment(
                              value: AiProvider.claude,
                              label: Text(l.t('provider_claude'))),
                        ],
                        selected: {settings.aiProvider},
                        onSelectionChanged: (v) => s.settings
                            .update(settings.copyWith(aiProvider: v.first)),
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        settings.hasApiKey ? Icons.key : Icons.key_off_outlined,
                        color: settings.hasApiKey ? Colors.green : null,
                      ),
                      title: Text(l.t(settings.aiProvider == AiProvider.gemini
                          ? 'gemini_key'
                          : 'api_key')),
                      subtitle: Text(l.t(
                          settings.hasApiKey ? 'api_key_set' : 'api_key_not_set')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _editApiKey(context),
                    ),
                    if (settings.aiProvider == AiProvider.gemini &&
                        settings.hasApiKey)
                      ListTile(
                        leading: const Icon(Icons.wifi_tethering),
                        title: Text(l.t('key_check')),
                        onTap: () => _checkGeminiKey(context),
                      ),
                  ],
                ),
              ),
            ],
            SectionHeader(l.t('notifications')),
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: Text(l.t('notifications')),
                subtitle: Text(l.t('notifications_desc')),
                value: settings.notificationsEnabled,
                onChanged: (b) async {
                  await s.settings
                      .update(settings.copyWith(notificationsEnabled: b));
                  if (b) {
                    await s.notifications.requestPermission();
                  } else {
                    await s.notifications.cancelAll();
                  }
                },
              ),
            ),
            SectionHeader(l.t('backup')),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.upload_file),
                    title: Text(l.t('backup_export')),
                    subtitle: Text(l.t('backup_export_desc')),
                    onTap: () async {
                      try {
                        await s.backup.exportAndShare(s.farm);
                        if (context.mounted) showSnack(context, l.t('backup_done'));
                      } catch (e) {
                        if (context.mounted) {
                          showSnack(context, '${l.t('error')}: $e');
                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_backup_restore),
                    title: Text(l.t('backup_import')),
                    subtitle: Text(l.t('backup_import_desc')),
                    onTap: () async {
                      if (!await confirmDialog(
                          context, l.t('backup_import_confirm'))) {
                        return;
                      }
                      try {
                        final ok = await s.backup.pickAndRestore(s.farm);
                        if (ok && context.mounted) {
                          await s.notifications.cancelAll();
                          if (context.mounted) {
                            showSnack(context, l.t('restore_done'));
                          }
                        }
                      } on FormatException {
                        if (context.mounted) {
                          showSnack(context, l.t('backup_invalid'));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showSnack(context, '${l.t('error')}: $e');
                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_forever_outlined,
                        color: Theme.of(context).colorScheme.error),
                    title: Text(l.t('clear_data'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    onTap: () async {
                      if (!await confirmDialog(
                          context, l.t('clear_data_confirm'),
                          confirmLabel: l.t('delete'))) {
                        return;
                      }
                      await s.notifications.cancelAll();
                      await s.farm.clearAll();
                      if (context.mounted) showSnack(context, l.t('deleted'));
                    },
                  ),
                ],
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: Text(l.t('data_safety')),
                subtitle: Text(l.t('data_safety_desc')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const DataScreen())),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.auto_awesome, color: Color(0xFFF9A825)),
                title: Text(l.t('demo_title')),
                subtitle: Text(l.t('demo_desc')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => loadDemoFarm(context),
              ),
            ),
            SectionHeader(l.t('about')),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l.t('app_name')),
                subtitle: Text('${l.t('version')} $appVersion'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editApiKey(BuildContext context) async {
    final s = AppScope.of(context);
    final l = context.l;
    final gemini = s.settings.value.aiProvider == AiProvider.gemini;
    final ctrl = TextEditingController(text: s.settings.value.activeKey);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t(gemini ? 'gemini_key' : 'api_key')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: ctrl,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                    hintText: gemini ? 'AIza… / AQ.…' : l.t('api_key_hint')),
                validator: (v) {
                  final e = gemini ? Validators.geminiKey(v) : Validators.apiKey(v);
                  return e == null ? null : l.t(e);
                },
              ),
              const SizedBox(height: 8),
              Text(l.t(gemini ? 'gemini_key_help' : 'claude_key_help'),
                  style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(l.t('api_key_help'),
                  style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          if (s.settings.value.hasApiKey)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: Text(l.t('delete')),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.t('cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, ctrl.text.trim());
              }
            },
            child: Text(l.t('save')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) {
      await s.settings.update(gemini
          ? s.settings.value.copyWith(geminiKey: result)
          : s.settings.value.copyWith(apiKey: result));
      if (gemini && result.isNotEmpty && context.mounted) {
        await _checkGeminiKey(context);
      }
    }
  }

  Future<void> _checkGeminiKey(BuildContext context) async {
    final s = AppScope.of(context);
    final l = context.l;
    showSnack(context, l.t('key_checking'));
    try {
      final model = await s.ai.checkGeminiKey(s.settings.value.geminiKey);
      if (context.mounted) showSnack(context, l.f('key_ok', [model]));
    } on ClaudeApiException catch (e) {
      if (context.mounted) {
        showSnack(context, l.f('key_failed', [l.aiError(e.message)]));
      }
    }
  }
}
