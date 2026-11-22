import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/navigation/app_router.dart';
import '../../shared/widgets/common.dart';
import 'crop_guide.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  String _query = '';

  /// Бахши интихобшуда; null — ҳама бахшҳо.
  String? _category;

  @override
  Widget build(BuildContext context) {
    final kb = AppScope.of(context).knowledge;
    final l = context.l;
    final found = kb.search(_query);
    final sections = [
      for (final c in kb.categories)
        if (_category == null || _category == c)
          (c, found.where((g) => g.category == c).toList()),
    ].where((s) => s.$2.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l.t('knowledge'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text('${l.t('knowledge_subtitle')} · ${kb.guides.length}',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: l.t('search'),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip(l.t('all'), null, kb.guides.length),
                for (final c in kb.categories)
                  if (kb.inCategory(c).isNotEmpty)
                    _chip(
                      '${KnowledgeBase.categoryIcon[c] ?? ''} '
                      '${KnowledgeBase.categoryLabel(c, l.lang)}',
                      c,
                      kb.inCategory(c).length,
                    ),
              ],
            ),
          ),
          if (sections.isEmpty)
            EmptyState(icon: Icons.search_off, title: l.t('nothing_found'))
          else
            for (final (c, list) in sections) ...[
              SectionHeader(
                '${KnowledgeBase.categoryIcon[c] ?? ''} '
                '${KnowledgeBase.categoryLabel(c, l.lang)} (${list.length})',
              ),
              for (final g in list) _GuideTile(g),
            ],
        ],
      ),
    );
  }

  Widget _chip(String label, String? category, int count) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text('$label · $count'),
          selected: _category == category,
          onSelected: (_) => setState(() => _category = category),
        ),
      );
}

class _GuideTile extends StatelessWidget {
  const _GuideTile(this.g);

  final CropGuide g;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Text(g.icon, style: const TextStyle(fontSize: 32)),
            title: Text(
              context.l.lang == 'ru' && g.nameRu.isNotEmpty ? '${g.name} · ${g.nameRu}' : g.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${g.latin}\n${g.summary}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
            onTap: () => AppRouter.cropGuide(context, g),
          ),
        ),
      );
}
