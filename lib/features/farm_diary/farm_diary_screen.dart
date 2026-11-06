import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/labels.dart';
import '../../core/navigation/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction.dart';
import '../../shared/widgets/common.dart';

class FarmDiaryScreen extends StatefulWidget {
  const FarmDiaryScreen({super.key});

  @override
  State<FarmDiaryScreen> createState() => _FarmDiaryScreenState();
}

class _FarmDiaryScreenState extends State<FarmDiaryScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('farm_diary')),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l.t('tab_finance')),
            Tab(text: l.t('tab_harvest')),
            Tab(text: l.t('tab_summary')),
          ],
        ),
      ),
      floatingActionButton: switch (_tabs.index) {
        0 => FloatingActionButton.extended(
            heroTag: 'add_tx',
            onPressed: () => _addTransaction(context),
            icon: const Icon(Icons.add),
            label: Text(l.t('new_transaction')),
          ),
        1 => FloatingActionButton.extended(
            heroTag: 'add_harvest',
            onPressed: () => AppRouter.harvestForm(context),
            icon: const Icon(Icons.add),
            label: Text(l.t('new_harvest')),
          ),
        _ => null,
      },
      body: TabBarView(
        controller: _tabs,
        children: const [_FinanceTab(), _HarvestTab(), _SummaryTab()],
      ),
    );
  }

  Future<void> _addTransaction(BuildContext context) async {
    final l = context.l;
    final type = await showModalBottomSheet<TransactionType>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.remove_circle_outline, color: AppColors.expense),
              title: Text(l.t('expense')),
              onTap: () => Navigator.pop(ctx, TransactionType.expense),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: AppColors.income),
              title: Text(l.t('income')),
              onTap: () => Navigator.pop(ctx, TransactionType.income),
            ),
          ],
        ),
      ),
    );
    if (type != null && context.mounted) {
      await AppRouter.transactionForm(context, type: type);
    }
  }
}

class _FinanceTab extends StatelessWidget {
  const _FinanceTab();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = context.l;
    return ListenableBuilder(
      listenable: s.farm,
      builder: (context, _) {
        final list = s.farm.transactionsSorted;
        if (list.isEmpty) {
          return EmptyState(
              icon: Icons.receipt_long_outlined, title: l.t('no_transactions'));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final t = list[i];
            final income = t.type == TransactionType.income;
            final plot = s.farm.plotById(t.plotId);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    (income ? AppColors.income : AppColors.expense).withValues(alpha: 0.12),
                child: Icon(
                  income ? Icons.south_west : Icons.north_east,
                  color: income ? AppColors.income : AppColors.expense,
                ),
              ),
              title: Text(l.category(t.category)),
              subtitle: Text([
                formatDate(t.date),
                if (plot != null) plot.name,
                if (t.note?.isNotEmpty == true) t.note!,
              ].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Text(
                '${income ? '+' : '−'}${formatMoney(t.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: income ? AppColors.income : AppColors.expense,
                ),
              ),
              onTap: () {
                // Даромади аз ҳосил сохташуда тавассути ҳосил таҳрир мешавад.
                if (t.harvestId != null) {
                  final h = s.farm.harvests.where((h) => h.id == t.harvestId);
                  if (h.isNotEmpty) {
                    AppRouter.harvestForm(context, harvest: h.first);
                    return;
                  }
                }
                AppRouter.transactionForm(context, transaction: t, type: t.type);
              },
            );
          },
        );
      },
    );
  }
}

class _HarvestTab extends StatelessWidget {
  const _HarvestTab();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = context.l;
    return ListenableBuilder(
      listenable: s.farm,
      builder: (context, _) {
        final list = s.farm.harvestsSorted;
        if (list.isEmpty) {
          return EmptyState(icon: Icons.agriculture_outlined, title: l.t('no_harvests'));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final h = list[i];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.agriculture)),
              title: Text('${h.cropName} · ${formatNumber(h.quantityKg)} ${l.t('kg')}'),
              subtitle: Text([
                formatDate(h.date),
                s.farm.plotById(h.plotId)?.name ?? '',
                l.quality(h.quality),
              ].where((e) => e.isNotEmpty).join(' · ')),
              trailing: h.totalValue > 0 ? Text(formatMoney(h.totalValue)) : null,
              onTap: () => AppRouter.harvestForm(context, harvest: h),
            );
          },
        );
      },
    );
  }
}

enum _Period { month, year, all }

class _SummaryTab extends StatefulWidget {
  const _SummaryTab();

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> {
  _Period _period = _Period.year;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = context.l;
    return ListenableBuilder(
      listenable: s.farm,
      builder: (context, _) {
        final now = DateTime.now();
        final from = switch (_period) {
          _Period.month => DateTime(now.year, now.month, 1),
          _Period.year => DateTime(now.year, 1, 1),
          _Period.all => null,
        };
        final sum = s.farm.summary(from: from);
        final cats = sum.expenseByCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final maxCat = cats.isEmpty ? 1.0 : cats.first.value;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<_Period>(
              segments: [
                ButtonSegment(value: _Period.month, label: Text(l.t('period_month'))),
                ButtonSegment(value: _Period.year, label: Text(l.t('period_year'))),
                ButtonSegment(value: _Period.all, label: Text(l.t('period_all'))),
              ],
              selected: {_period},
              onSelectionChanged: (v) => setState(() => _period = v.first),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.south_west,
                    label: l.t('income'),
                    value: formatMoney(sum.income),
                    color: AppColors.income,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    icon: Icons.north_east,
                    label: l.t('expense'),
                    value: formatMoney(sum.expense),
                    color: AppColors.expense,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            StatTile(
              icon: Icons.account_balance_wallet_outlined,
              label: l.t('balance'),
              value: formatMoney(sum.balance),
              color: sum.balance >= 0 ? AppColors.income : AppColors.expense,
            ),
            SectionHeader(l.t('by_category')),
            if (cats.isEmpty)
              Card(child: ListTile(title: Text(l.t('no_transactions'))))
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      for (final e in cats)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(l.category(e.key))),
                                  Text(formatMoney(e.value),
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: e.value / maxCat,
                                color: AppColors.expense,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (s.farm.plots.isNotEmpty) ...[
              SectionHeader(l.t('by_plot')),
              Card(
                child: Column(
                  children: [
                    for (final p in s.farm.plots)
                      Builder(builder: (context) {
                        final ps = s.farm.summary(from: from, plotId: p.id);
                        return ListTile(
                          title: Text(p.name),
                          subtitle: Text(
                              '+${formatMoney(ps.income)}  −${formatMoney(ps.expense)}'),
                          trailing: Text(
                            formatMoney(ps.balance),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: ps.balance >= 0
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
