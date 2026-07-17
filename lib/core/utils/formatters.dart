import 'package:intl/intl.dart';

/// Same locale/currency the web POS uses so both terminals speak the same
/// language: Nicaragua córdoba (`C$`) with es-NI number formatting.
class Formatters {
  Formatters._();

  static final NumberFormat _number = NumberFormat.decimalPatternDigits(
    locale: 'es_NI',
    decimalDigits: 2,
  );

  static final DateFormat _dateTime = DateFormat('d/M/yy, HH:mm', 'es_NI');
  static final DateFormat _date = DateFormat('d/M/yyyy', 'es_NI');

  static String money(dynamic value) {
    final n = value is num ? value : double.parse(value.toString());
    return 'C\$${_number.format(n)}';
  }

  static String dateTime(DateTime value) => _dateTime.format(value.toLocal());
  static String date(DateTime value) => _date.format(value.toLocal());
}
