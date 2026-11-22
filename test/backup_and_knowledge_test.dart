import 'dart:convert';
import 'dart:io';

import 'package:agro_ai/data/local/farm_store.dart';
import 'package:agro_ai/data/local/local_store.dart';
import 'package:agro_ai/data/repositories/farm_repository.dart';
import 'package:agro_ai/features/knowledge/crop_guide.dart';
import 'package:agro_ai/models/plot.dart';
import 'package:agro_ai/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup roundtrip restores all data', () async {
    final a = FarmRepository(JsonFarmStore(MemoryStore()));
    await a.load();
    await a.savePlot(Plot(id: 'p', name: 'Қитъа', areaHa: 3, createdAt: DateTime(2026)));
    final raw = BackupService.encode(a);

    final b = FarmRepository(JsonFarmStore(MemoryStore()));
    await b.load();
    await b.replaceAll(BackupService.decode(raw));
    expect(b.plots.single.name, 'Қитъа');
    expect(b.totalAreaHa, 3);
  });

  test('invalid backup is rejected', () {
    expect(() => BackupService.decode('hello'), throwsFormatException);
    expect(() => BackupService.decode('{"format":"other","data":{}}'),
        throwsFormatException);
    expect(() => BackupService.decode('[1,2]'), throwsFormatException);
  });

  group('knowledge base', () {
    final kb = KnowledgeBase.parse(
        File('assets/data/crop_guides_tg.json').readAsStringSync());

    test('all guides are complete', () {
      expect(kb.guides.length, greaterThanOrEqualTo(30));
      final ids = <String>{};
      for (final g in kb.guides) {
        expect(ids.add(g.id), isTrue, reason: 'duplicate id ${g.id}');
        expect(g.name, isNotEmpty);
        expect(g.sowingTime, isNotEmpty, reason: g.id);
        expect(g.watering, isNotEmpty, reason: g.id);
        expect(g.diseases, isNotEmpty, reason: g.id);
      }
    });

    test('search and lookup', () {
      expect(kb.search('пахта').single.id, 'cotton');
      expect(kb.search('фитофтороз').map((g) => g.id), containsAll(['potato', 'tomato']));
      expect(kb.findByName('Гандум')?.id, 'wheat');
      expect(kb.findByName('гандуми тирамоҳӣ')?.id, 'wheat');
      expect(kb.findByName(''), isNull);
      expect(kb.findByName('ананас'), isNull);
      expect(kb.findByName('Олуболу')?.id, 'cherry');
      expect(kb.findByName('Олу')?.id, 'plum');
      expect(kb.findByName('Зардолу')?.id, 'apricot');
      expect(kb.findByName('Слива')?.id, 'plum');
      expect(kb.findByName('Хлопок')?.id, 'cotton');
      expect(kb.findByName('Вишня / черешня')?.id, 'cherry');
      expect(kb.search('люцерна').single.id, 'alfalfa');
      for (final g in kb.guides) {
        expect(g.nameRu, isNotEmpty, reason: g.id);
      }
    });

    test('every guide is in a named section', () {
      expect(kb.categories, containsAll(['Мевагӣ', 'Сабзавот', 'Ангур ва буттамева', 'Ғалладона']));
      for (final c in kb.categories) {
        expect(kb.inCategory(c), isNotEmpty, reason: c);
        expect(KnowledgeBase.categoryRu[c], isNotNull, reason: c);
        expect(KnowledgeBase.categoryIcon[c], isNotNull, reason: c);
      }
      expect(kb.inCategory('Мевагӣ').map((g) => g.id), containsAll(['apple', 'apricot', 'plum']));
      expect(KnowledgeBase.categoryLabel('Мевагӣ', 'ru'), 'Фрукты');
      expect(kb.guides.map((g) => g.category).toSet().length, kb.categories.length);
    });

    test('produce guides point to existing articles', () {
      final d = jsonDecode(File('assets/data/diseases_tg.json').readAsStringSync()) as Map;
      final ids = kb.guides.map((g) => g.id).toSet();
      for (final e in (d['produce'] as Map).entries) {
        final g = (e.value as Map)['guide'];
        if (g != null) expect(ids, contains(g), reason: e.key);
      }
    });
  });
}
