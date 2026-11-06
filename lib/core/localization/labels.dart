import '../../models/crop_cycle.dart';
import '../../models/harvest.dart';
import '../../models/irrigation.dart';
import '../../models/plant_scan.dart';
import '../../models/plot.dart';
import '../../models/transaction.dart';
import 'app_strings.dart';

/// Тарҷумаи қиматҳои enum.
extension EnumLabels on L10n {
  String soil(SoilType s) => t('soil_${s.name}');
  String cycleStatus(CycleStatus s) => t('status_${s.name}');
  String method(IrrigationMethod m) => t('method_${m.name}');
  String category(TransactionCategory c) => t('cat_${c.name}');
  String txType(TransactionType tt) => t(tt.name);
  String quality(HarvestQuality q) => t('quality_${q.name}');
  String severity(Severity s) =>
      s == Severity.none ? t('none') : t('severity_${s.name}');

  /// «Имрӯз», «Фардо», «баъд аз 3 рӯз», «гузаштааст».
  String relativeDay(DateTime date, [DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = d.difference(today).inDays;
    if (diff < 0) return t('overdue');
    if (diff == 0) return t('today');
    if (diff == 1) return t('tomorrow');
    return f('in_days', [diff]);
  }
}
