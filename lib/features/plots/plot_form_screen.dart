import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/labels.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/id.dart';
import '../../core/validation/validators.dart';
import '../../models/plot.dart';
import '../../shared/widgets/common.dart';

class PlotFormScreen extends StatefulWidget {
  const PlotFormScreen({super.key, this.plot});

  final Plot? plot;

  @override
  State<PlotFormScreen> createState() => _PlotFormScreenState();
}

class _PlotFormScreenState extends State<PlotFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.plot?.name);
  late final _area = TextEditingController(
      text: widget.plot == null ? '' : formatNumber(widget.plot!.areaHa));
  late final _location = TextEditingController(text: widget.plot?.location);
  late final _notes = TextEditingController(text: widget.plot?.notes);
  late SoilType _soil = widget.plot?.soilType ?? SoilType.loam;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final farm = AppScope.of(context).farm;
    final l = context.l;
    final old = widget.plot;
    final plot = Plot(
      id: old?.id ?? newId(),
      name: _name.text.trim(),
      areaHa: Validators.parseNumber(_area.text)!,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      soilType: _soil,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdAt: old?.createdAt ?? DateTime.now(),
    );
    await farm.savePlot(plot);
    if (!mounted) return;
    showSnack(context, l.t('saved'));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    String? v(String? key) => key == null ? null : l.t(key);
    return Scaffold(
      appBar: AppBar(
          title: Text(l.t(widget.plot == null ? 'new_plot' : 'edit_plot'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('plot_name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.t('plot_name'),
                prefixIcon: const Icon(Icons.label_outline),
              ),
              validator: (s) =>
                  v(Validators.required(s) ?? Validators.maxLength(s, 60)),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('plot_area'),
              controller: _area,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l.t('plot_area'),
                prefixIcon: const Icon(Icons.straighten),
                suffixText: l.t('ha'),
              ),
              validator: (s) => v(Validators.positiveNumber(s)),
            ),
            const SizedBox(height: 14),
            EnumDropdown<SoilType>(
              label: l.t('plot_soil'),
              icon: Icons.terrain_outlined,
              value: _soil,
              items: SoilType.values,
              itemLabel: l.soil,
              onChanged: (s) => setState(() => _soil = s),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _location,
              decoration: InputDecoration(
                labelText: '${l.t('plot_location')} (${l.t('optional')})',
                prefixIcon: const Icon(Icons.place_outlined),
              ),
              validator: (s) => v(Validators.maxLength(s, 120)),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: '${l.t('notes')} (${l.t('optional')})',
                prefixIcon: const Icon(Icons.notes),
              ),
              validator: (s) => v(Validators.maxLength(s, 1000)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('save'),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(l.t('save')),
            ),
          ],
        ),
      ),
    );
  }
}
