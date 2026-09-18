/// Time windows the barber dashboard can be filtered by. Values match the
/// `period` query param the backend accepts (`/dashboard/barber`), and the
/// labels mirror the web client so both surfaces read the same.
enum DashboardPeriod {
  day('day', 'Hoy', 'hoy'),
  yesterday('yesterday', 'Ayer', 'ayer'),
  week('week', 'Semana', 'esta semana'),
  month('month', 'Mes', 'este mes');

  const DashboardPeriod(this.value, this.label, this.phrase);

  /// Query-param value sent to the API.
  final String value;

  /// Short label for the period selector.
  final String label;

  /// Reads naturally inside a sentence: "Tu ganancia esta semana".
  final String phrase;

  String get servicesLabel => 'Servicios realizados $phrase';
}
