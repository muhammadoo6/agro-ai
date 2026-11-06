import 'package:intl/intl.dart';

final _date = DateFormat('dd.MM.yyyy');
final _dateTime = DateFormat('dd.MM.yyyy HH:mm');
final _money = NumberFormat('#,##0.##', 'en_US');

String formatDate(DateTime d) => _date.format(d);
String formatDateTime(DateTime d) => _dateTime.format(d);

/// Маблағ бо сомонӣ, масалан: 1 250,5 смн
String formatMoney(double v) =>
    '${_money.format(v).replaceAll(',', ' ').replaceAll('.', ',')} смн';

String formatNumber(double v) =>
    _money.format(v).replaceAll(',', ' ').replaceAll('.', ',');

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
