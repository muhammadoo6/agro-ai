import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/labels.dart';
import '../../core/utils/id.dart';
import '../../core/validation/validators.dart';
import '../../models/crop_cycle.dart';
import '../../shared/widgets/common.dart';

class CropCycleFormScreen extends StatefulWidget {
  const CropCycleFormScreen({super.key, required this.plotId, this.cycle});

  final String plotId;
  final CropCycle? cycle;

  @override
  State<CropCycleFormScreen> createState() => _CropCycleFormScreenState();
}

class _CropCycleFormScreenState extends State<CropCycleFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _crop = TextEditingController(text: widget.cycle?.cropName);
  late final _variety = TextEditingController(text: widget.cycle?.variety);
  late final _notes = TextEditingController(text: widget.cycle?.notes);
  late DateTime _planting = widget.cycle?.plantingDate ?? DateTime.now();
  late DateTime? _harvest = widget.cycle?.expectedHarvestDate;
  late CycleStatus _status = widget.cycle?.status ?? CycleStatus.growing;
  String? _dateError;

  @override
  void dispose() {
    _crop.dispose();
    _variety.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Агар зироат дар донишнома бошад, санаи ҳосилро худкор пешниҳод мекунем.
  void _suggestHarvest(String crop) {
    if (_harvest != null) return;
    final guide = AppScope.of(context).knowledge.findByName(crop);
    if (guide != null && guide.growingDays > 0) {
      setState(() =>
          _harvest = _planting.add(Duration(days: guide.growingDays)));
    }
  }

  Future<void> _save() async {
    final err = Validators.dateOrder(_planting, _harvest);
    setState(() => _dateError = err);
    if (!_form.currentState!.validate() || err != null) return;
    final farm = AppScope.of(context).farm;
    final l = context.l;
    await farm.saveCycle(CropCycle(
      id: widget.cycle?.id ?? newId(),
      plotId: widget.plotId,
      cropName: _crop.text.trim(),
      variety: _variety.text.trim().isEmpty ? null : _variety.text.trim(),
      plantingDate: _planting,
      expectedHarvestDate: _harvest,
      status: _status,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    ));
    if (!mounted) return;
    showSnack(context, l.t('saved'));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final guides = AppScope.of(context).knowledge.guides;
    String? v(String? key) => key == null ? null : l.t(key);
    return Scaffold(
      appBar: AppBar(
          title: Text(l.t(widget.cycle == null ? 'new_cycle' : 'edit_cycle'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('crop_name'),
              controller: _crop,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.t('crop_name'),
                prefixIcon: const Icon(Icons.eco_outlined),
              ),
              validator: (s) =>
                  v(Validators.required(s) ?? Validators.maxLength(s, 60)),
              onFieldSubmitted: _suggestHarvest,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final g in guides)
                  ActionChip(
                    label: Text('${g.icon} ${g.name}'),
                    onPressed: () {
                      _crop.text = g.name;
                      _suggestHarvest(g.name);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _variety,
              decoration: InputDecoration(
                labelText: '${l.t('variety')} (${l.t('optional')})',
                prefixIcon: const Icon(Icons.local_florist_outlined),
              ),
              validator: (s) => v(Validators.maxLength(s, 60)),
            ),
            const SizedBox(height: 14),
            DateField(
              label: l.t('planting_date'),
              value: _planting,
              onChanged: (d) => setState(() => _planting = d ?? _planting),
            ),
            const SizedBox(height: 14),
            DateField(
              label: '${l.t('expected_harvest')} (${l.t('optional')})',
              value: _harvest,
              clearable: true,
              errorText: _dateError == null ? null : l.t(_dateError!),
              onChanged: (d) => setState(() => _harvest = d),
            ),
            const SizedBox(height: 14),
            EnumDropdown<CycleStatus>(
              label: l.t('status'),
              icon: Icons.flag_outlined,
              value: _status,
              items: CycleStatus.values,
              itemLabel: l.cycleStatus,
              onChanged: (s) => setState(() => _status = s),
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
