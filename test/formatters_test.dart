import 'package:agro_ai/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatNumber uses comma decimal and space thousands', () {
    expect(formatNumber(1.5), '1,5');
    expect(formatNumber(1250), '1 250');
    expect(formatNumber(0.25), '0,25');
  });

  test('formatMoney', () {
    expect(formatMoney(1250.5), '1 250,5 смн');
  });

  test('formatDate', () {
    expect(formatDate(DateTime(2026, 4, 9)), '09.04.2026');
  });
}
