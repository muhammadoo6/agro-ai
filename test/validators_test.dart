import 'package:agro_ai/core/validation/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('required', () {
    expect(Validators.required(null), 'err_required');
    expect(Validators.required('  '), 'err_required');
    expect(Validators.required('a'), isNull);
  });

  test('parseNumber accepts comma and spaces', () {
    expect(Validators.parseNumber('1,5'), 1.5);
    expect(Validators.parseNumber('1 250.75'), 1250.75);
    expect(Validators.parseNumber('abc'), isNull);
    expect(Validators.parseNumber(''), isNull);
  });

  test('positiveNumber', () {
    expect(Validators.positiveNumber('0'), 'err_positive');
    expect(Validators.positiveNumber('-1'), 'err_positive');
    expect(Validators.positiveNumber('x'), 'err_number');
    expect(Validators.positiveNumber(''), 'err_required');
    expect(Validators.positiveNumber('', allowEmpty: true), isNull);
    expect(Validators.positiveNumber('2,5'), isNull);
    expect(Validators.positiveNumber('99999999999'), 'err_too_big');
  });

  test('nonNegativeNumber', () {
    expect(Validators.nonNegativeNumber(''), isNull);
    expect(Validators.nonNegativeNumber('0'), isNull);
    expect(Validators.nonNegativeNumber('-3'), 'err_positive');
  });

  test('dateOrder', () {
    final a = DateTime(2026, 4, 1);
    expect(Validators.dateOrder(a, null), isNull);
    expect(Validators.dateOrder(a, DateTime(2026, 3, 1)), 'err_date_order');
    expect(Validators.dateOrder(a, a), isNull);
  });

  test('apiKey', () {
    expect(Validators.apiKey(''), isNull);
    expect(Validators.apiKey('hello'), 'err_api_key');
    expect(Validators.apiKey('sk-ant-api03-xxxxxxxxxxxxxxxx'), isNull);
  });

  test('maxLength', () {
    expect(Validators.maxLength('abc', 2), 'err_too_long');
    expect(Validators.maxLength('ab', 2), isNull);
  });
}
