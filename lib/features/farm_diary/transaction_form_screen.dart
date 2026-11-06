import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/labels.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/id.dart';
import '../../core/validation/validators.dart';
import '../../models/transaction.dart';
import '../../shared/widgets/common.dart';

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({
    super.key,
    this.transaction,
    this.initialType = TransactionType.expense,
    this.plotId,
  });

  final FarmTransaction? transaction;
  final TransactionType initialType;
  final String? plotId;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _form = GlobalKey<FormState>();
  late TransactionType _type = widget.transaction?.type ?? widget.initialType;
  late TransactionCategory _category = widget.transaction?.category ??
      (_type == TransactionType.income
          ? TransactionCategory.sale
          : TransactionCategory.seeds);
  late final _amount = TextEditingController(
      text: widget.transaction == null ? '' : formatNumber(widget.transaction!.amount));
  late final _note = TextEditingController(text: widget.transaction?.note);
  late DateTime _date = widget.transaction?.date ?? DateTime.now();
  late String? _plotId = widget.transaction?.plotId ?? widget.plotId;

  List<TransactionCategory> get _cats => _type == TransactionType.income
      ? TransactionCategory.incomeCategories
      : TransactionCategory.expenseCategories;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final farm = AppScope.of(context).farm;
    final l = context.l;
    await farm.saveTransaction(FarmTransaction(
      id: widget.transaction?.id ?? newId(),
      type: _type,
      category: _category,
      amount: Validators.parseNumber(_amount.text)!,
      date: _date,
      plotId: _plotId,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    ));
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
    await farm.deleteTransaction(widget.transaction!.id);
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
            widget.transaction == null ? 'new_transaction' : 'edit_transaction')),
        actions: [
          if (widget.transaction != null)
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
            SegmentedButton<TransactionType>(
              segments: [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text(l.t('expense')),
                  icon: const Icon(Icons.north_east),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text(l.t('income')),
                  icon: const Icon(Icons.south_west),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                if (!_cats.contains(_category)) _category = _cats.first;
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l.t('amount'),
                prefixIcon: const Icon(Icons.payments_outlined),
                suffixText: 'смн',
              ),
              validator: (s) => v(Validators.positiveNumber(s)),
            ),
            const SizedBox(height: 14),
            Text(l.t('category'), style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in _cats)
                  ChoiceChip(
                    label: Text(l.category(c)),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            DateField(
              label: l.t('date'),
              value: _date,
              onChanged: (d) => setState(() => _date = d ?? _date),
            ),
            const SizedBox(height: 14),
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
                  DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
              ],
              onChanged: (s) => setState(() => _plotId = s),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _note,
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
