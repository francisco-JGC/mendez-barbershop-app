/// Central place for backend API paths. Base URL is injected via env at DI time.
class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Sales
  static const String sales = '/sales';
  static String saleById(String id) => '/sales/$id';
}
