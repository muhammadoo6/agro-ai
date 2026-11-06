import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/navigation/app_router.dart';
import '../../shared/widgets/common.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final kb = AppScope.of(context).knowledge;
    final l = context.l;
    final list = kb.search(_query);
    return Scaffold(
      appBar: AppBar(title: Text(l.t('knowledge'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(l.t('knowledge_subtitle'),
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
          if (list.isEmpty)
            EmptyState(icon: Icons.search_off, title: l.t('nothing_found'))
          else
            for (final g in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Text(g.icon, style: const TextStyle(fontSize: 32)),
                    title: Text(g.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${g.category} · ${g.latin}\n${g.summary}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    onTap: () => AppRouter.cropGuide(context, g),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
