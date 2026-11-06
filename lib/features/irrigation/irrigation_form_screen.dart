import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/labels.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/id.dart';
import '../../core/validation/validators.dart';
import '../../models/irrigation.dart';
import '../../shared/widgets/common.dart';

class IrrigationFormScreen extends StatefulWidget {
  const IrrigationFormScreen({super.key, this.plotId, this.irrigation});

  final String? plotId;
  final Irrigation? irrigation;

  @override
  State<IrrigationFormScreen> createState() => _IrrigationFormScreenState();
}

class _IrrigationFormScreenState extends State<IrrigationFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _duration = TextEditingController(
      text: widget.irrigation?.durationMinutes.toString() ?? '60');
  late final _volume = TextEditingController(
      text: widget.irrigation?.volumeM3 == null
          ? ''
          : formatNumber(widget.irrigation!.volumeM3!));
  late final _notes = TextEditingController(text: widget.irrigation?.notes);
  String? _plotId;
  late DateTime _date = widget.irrigation?.date ?? DateTime.now();
  late IrrigationMethod _method =
      widget.irrigation?.method ?? IrrigationMethod.furrow;
  late DateTime? _next = widget.irrigation?.nextPlannedDate;
  late bool _remind = widget.irrigation?.remind ?? true;
  String? _nextError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_plotId == null) {
      final plots = AppScope.of(context).farm.plots;
      _plotId = widget.irrigation?.plotId ??
          widget.plotId ??
          (plots.isNotEmpty ? plots.first.id : null);
      _next ??= _date.add(const Duration(days: 7));
    }
  }

  @override
  void dispose() {
    _duration.dispose();
    _volume.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final err = Validators.dateOrder(_date, _next);
    setState(() => _nextError = err);
    if (!_form.currentState!.validate() || err != null || _plotId == null) {
      return;
    }
    final s = AppScope.of(context);
    final l = context.l;
    final irrigation = Irrigation(
      id: widget.irrigation?.id ?? newId(),
      plotId: _plotId!,
      date: _date,
      durationMinutes: Validators.parseNumber(_duration.text)!.round(),
      volumeM3: Validators.parseNumber(_volume.text),
      method: _method,
      nextPlannedDate: _next,
      remind: _remind && _next != null,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    await s.farm.saveIrrigation(irrigation);

    // Ёдраскунӣ: аввал кӯҳнаро бекор, баъд навро танзим мекунем.
    await s.notifications.cancel(irrigation.notificationId);
    if (irrigation.remind && s.settings.value.notificationsEnabled) {
      final plotName = s.farm.plotById(_plotId)?.name ?? '';
      await s.notifications.scheduleIrrigation(
        id: irrigation.notificationId,
        date: irrigation.nextPlannedDate!,
        title: l.t('notif_irrigation_title'),
        body: l.f('notif_irrigation_body', [plotName]),
      );
    }
    if (!mounted) return;
    showSnack(context, l.t('saved'));
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final s = AppScope.of(context);
    final l = context.l;
    final i = widget.irrigation!;
    if (!await confirmDialog(context, l.t('confirm_delete'),
        confirmLabel: l.t('delete'))) {
      return;
    }
    await s.notifications.cancel(i.notificationId);
    await s.farm.deleteIrrigation(i.id);
    if (!mounted) return;
    showSnack(context, l.t('deleted'));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final plots = AppScope.of(context).farm.plots;
    String? v(String? key) => key == null ? null : l.t(key);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.t(
            widget.irrigation == null ? 'new_irrigation' : 'edit_irrigation')),
        actions: [
          if (widget.irrigation != null)
            IconButton(
              tooltip: l.t('delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _plotId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l.t('plot'),
                prefixIcon: const Icon(Icons.landscape_outlined),
              ),
              items: [
                for (final p in plots)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              validator: (s) => s == null ? l.t('err_required') : null,
              onChanged: (s) => setState(() => _plotId = s),
            ),
            const SizedBox(height: 14),
            DateField(
              label: l.t('date'),
              value: _date,
              onChanged: (d) => setState(() => _date = d ?? _date),
            ),
            const SizedBox(height: 14),
            EnumDropdown<IrrigationMethod>(
              label: l.t('method'),
              icon: Icons.alt_route,
              value: _method,
              items: IrrigationMethod.values,
              itemLabel: l.method,
              onChanged: (m) => setState(() => _method = m),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('duration'),
                    controller: _duration,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l.t('duration_min'),
                      prefixIcon: const Icon(Icons.timer_outlined),
                    ),
                    validator: (s) => v(Validators.positiveNumber(s)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _volume,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l.t('volume_m3'),
                      prefixIcon: const Icon(Icons.water),
                    ),
                    validator: (s) => v(Validators.nonNegativeNumber(s)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DateField(
              label: l.t('next_irrigation'),
              value: _next,
              clearable: true,
              errorText: _nextError == null ? null : l.t(_nextError!),
              onChanged: (d) => setState(() => _next = d),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final d in const [3, 5, 7, 10, 14])
                  ActionChip(
                    label: Text('+$d'),
                    onPressed: () =>
                        setState(() => _next = _date.add(Duration(days: d))),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _remind && _next != null,
              onChanged: _next == null ? null : (b) => setState(() => _remind = b),
              title: Text(l.t('remind_me')),
              secondary: const Icon(Icons.notifications_outlined),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: '${l.t('notes')} (${l.t('optional')})',
                prefixIcon: const Icon(Icons.notes),
              ),
              validator: (s) => v(Validators.maxLength(s, 500)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('save'),
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(l.t('save')),
            ),
          ],
        ),
      ),
    );
  }
}
