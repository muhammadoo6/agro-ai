import 'dart:io';

import 'package:agro_ai/data/local/local_store.dart';
import 'package:agro_ai/data/repositories/farm_repository.dart';
import 'package:agro_ai/features/knowledge/crop_guide.dart';
import 'package:agro_ai/models/plot.dart';
import 'package:agro_ai/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup roundtrip restores all data', () async {
    final a = FarmRepository(MemoryStore());
    await a.load();
    await a.savePlot(Plot(id: 'p', name: 'Қитъа', areaHa: 3, createdAt: DateTime(2026)));
    final raw = BackupService.encode(a);

    final b = FarmRepository(MemoryStore());
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
      expect(kb.guides.length, greaterThanOrEqualTo(8));
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
    });
  });
}
