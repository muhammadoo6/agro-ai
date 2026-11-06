import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/labels.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/id.dart';
import '../../core/validation/validators.dart';
import '../../models/harvest.dart';
import '../../shared/widgets/common.dart';

class HarvestFormScreen extends StatefulWidget {
  const HarvestFormScreen({super.key, this.harvest, this.plotId});

  final Harvest? harvest;
  final String? plotId;

  @override
  State<HarvestFormScreen> createState() => _HarvestFormScreenState();
}

class _HarvestFormScreenState extends State<HarvestFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _crop = TextEditingController(text: widget.harvest?.cropName);
  late final _qty = TextEditingController(
      text: widget.harvest == null ? '' : formatNumber(widget.harvest!.quantityKg));
  late final _price = TextEditingController(
      text: widget.harvest?.pricePerKg == null
          ? ''
          : formatNumber(widget.harvest!.pricePerKg!));
  late final _notes = TextEditingController(text: widget.harvest?.notes);
  late DateTime _date = widget.harvest?.date ?? DateTime.now();
  late HarvestQuality _quality = widget.harvest?.quality ?? HarvestQuality.medium;
  String? _plotId;
  bool _asIncome = true;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final farm = AppScope.of(context).farm;
    _plotId = widget.harvest?.plotId ??
        widget.plotId ??
        (farm.plots.isNotEmpty ? farm.plots.first.id : null);
    if (widget.harvest != null) {
      _asIncome = farm.harvestHasIncome(widget.harvest!.id);
    }
    _fillCropFromPlot();
  }

  void _fillCropFromPlot() {
    if (_crop.text.trim().isNotEmpty || _plotId == null) return;
    final c = AppScope.of(context).farm.activeCycleForPlot(_plotId!);
    if (c != null) _crop.text = c.cropName;
  }

  @override
  void dispose() {
    _crop.dispose();
    _qty.dispose();
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  double get _total =>
      (Validators.parseNumber(_qty.text) ?? 0) *
      (Validators.parseNumber(_price.text) ?? 0);

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _plotId == null) return;
    final farm = AppScope.of(context).farm;
    final l = context.l;
    final cycle = farm.activeCycleForPlot(_plotId!);
    await farm.saveHarvest(
      Harvest(
        id: widget.harvest?.id ?? newId(),
        plotId: _plotId!,
        cycleId: widget.harvest?.cycleId ?? cycle?.id,
        cropName: _crop.text.trim(),
        date: _date,
        quantityKg: Validators.parseNumber(_qty.text)!,
        pricePerKg: Validators.parseNumber(_price.text),
        quality: _quality,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
      asIncome: _asIncome,
    );
    if (!mounted) return;
    showSnack(context, l.t('saved'));
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final farm = AppScope.of(context).farm;
    final l = context.l;
    if (!await confirmDialog(context, l.t('confirm_delete'),
        confirmLabel: l.t('delete'))) {
      return;
    }
    await farm.deleteHarvest(widget.harvest!.id);
    if (!mounted) return;
    showSnack(context, l.t('deleted'));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final plots = AppScope.of(context).farm.plots;
    String? v(String? key) => key == null ? null : l.t(key);
    if (plots.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l.t('new_harvest'))),
        body: EmptyState(
          icon: Icons.landscape_outlined,
          title: l.t('no_plots'),
          message: l.t('no_plots_hint'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l.t(widget.harvest == null ? 'new_harvest' : 'edit_harvest')),
        actions: [
          if (widget.harvest != null)
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
              onChanged: (s) => setState(() {
                _plotId = s;
                _fillCropFromPlot();
              }),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _crop,
              decoration: InputDecoration(
                labelText: l.t('crop_name'),
                prefixIcon: const Icon(Icons.eco_outlined),
              ),
              validator: (s) =>
                  v(Validators.required(s) ?? Validators.maxLength(s, 60)),
            ),
            const SizedBox(height: 14),
            DateField(
              label: l.t('date'),
              value: _date,
              onChanged: (d) => setState(() => _date = d ?? _date),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qty,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l.t('quantity_kg'),
                      prefixIcon: const Icon(Icons.scale_outlined),
                    ),
                    validator: (s) => v(Validators.positiveNumber(s)),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l.t('price_per_kg'),
                      prefixIcon: const Icon(Icons.sell_outlined),
                    ),
                    validator: (s) => v(Validators.nonNegativeNumber(s)),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (_total > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text('${l.t('harvest_value')}: ${formatMoney(_total)}',
                    style: Theme.of(context).textTheme.titleSmall),
              ),
            const SizedBox(height: 14),
            EnumDropdown<HarvestQuality>(
              label: l.t('quality'),
              icon: Icons.star_outline,
              value: _quality,
              items: HarvestQuality.values,
              itemLabel: l.quality,
              onChanged: (q) => setState(() => _quality = q),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _asIncome,
              onChanged: (b) => setState(() => _asIncome = b),
              title: Text(l.t('add_income_from_harvest')),
              secondary: const Icon(Icons.payments_outlined),
            ),
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
