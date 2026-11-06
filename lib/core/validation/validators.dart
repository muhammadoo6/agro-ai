/// Санҷиши маълумоти воридшуда.
///
/// Ҳар валидатор матни хаторо бо калиди тарҷума бармегардонад ё `null`.
/// Барои намоиш калидро тавассути `L10n.t` тарҷума кунед.
class Validators {
  static String? required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'err_required' : null;

  static String? maxLength(String? v, int max) =>
      (v != null && v.trim().length > max) ? 'err_too_long' : null;

  /// Рақами мусбат (ҷудокунандаи даҳӣ: нуқта ё вергул).
  static String? positiveNumber(String? v, {bool allowEmpty = false}) {
    if (v == null || v.trim().isEmpty) {
      return allowEmpty ? null : 'err_required';
    }
    final n = parseNumber(v);
    if (n == null) return 'err_number';
    if (n <= 0) return 'err_positive';
    if (n > 1e9) return 'err_too_big';
    return null;
  }

  static String? nonNegativeNumber(String? v, {bool allowEmpty = true}) {
    if (v == null || v.trim().isEmpty) {
      return allowEmpty ? null : 'err_required';
    }
    final n = parseNumber(v);
    if (n == null) return 'err_number';
    if (n < 0) return 'err_positive';
    if (n > 1e9) return 'err_too_big';
    return null;
  }

  static double? parseNumber(String? v) {
    if (v == null) return null;
    final s = v.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (s.isEmpty) return null;
    final n = double.tryParse(s);
    if (n == null || n.isNaN || n.isInfinite) return null;
    return n;
  }

  /// Санаи анҷом набояд аз санаи оғоз пештар бошад.
  static String? dateOrder(DateTime start, DateTime? end) =>
      (end != null && end.isBefore(start)) ? 'err_date_order' : null;

  static String? apiKey(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final s = v.trim();
    if (!s.startsWith('sk-ant-') || s.length < 20) return 'err_api_key';
    return null;
  }
}
