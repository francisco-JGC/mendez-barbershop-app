import 'package:shared_preferences/shared_preferences.dart';

/// Persists the barbershop code the seller entered on first launch.
///
/// Not a secret — the same code is entered on the web login page and is
/// visible in HTTP headers, so `SharedPreferences` is enough (no need for the
/// secure storage keychain).
class TenantCodeStorage {
  TenantCodeStorage(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'tenant.code';

  String? get() => _prefs.getString(_key);
  Future<void> set(String code) => _prefs.setString(_key, code);
  Future<void> clear() => _prefs.remove(_key);
}
