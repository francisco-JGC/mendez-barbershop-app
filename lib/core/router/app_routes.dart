class AppRoutes {
  AppRoutes._();

  static const String tenantCode = '/tenant-code';
  static const String login = '/login';
  static const String home = '/';
  static const String newSale = '/sales/new';
  static const String salesHistory = '/sales';
  static const String printerSettings = '/settings/printer';

  /// Barber-only surface. Lives outside the POS shell because barbers get a
  /// different app altogether, not extra tabs in the seller's. Both paths
  /// share the `/mi-dia` prefix so the router guard can tell the two areas
  /// apart with a single check.
  static const String barberDashboard = '/mi-dia';
  static const String barberHistory = '/mi-dia/historial';
}
