import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/infrastructure/datasources/auth_remote_data_source.dart';
import '../../features/auth/infrastructure/repositories/auth_repository_impl.dart';
import '../../features/catalog/domain/repositories/catalog_repository.dart';
import '../../features/catalog/infrastructure/datasources/catalog_remote_data_source.dart';
import '../../features/catalog/infrastructure/repositories/catalog_repository_impl.dart';
import '../../features/printer_settings/application/printer_connection_keeper.dart';
import '../../features/printer_settings/domain/services/printer_service.dart';
import '../../features/printer_settings/infrastructure/services/bluetooth_thermal_printer_service.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/settings/infrastructure/datasources/settings_remote_data_source.dart';
import '../../features/settings/infrastructure/repositories/settings_repository_impl.dart';
import '../../features/staff/domain/repositories/staff_repository.dart';
import '../../features/staff/infrastructure/datasources/staff_remote_data_source.dart';
import '../../features/staff/infrastructure/repositories/staff_repository_impl.dart';
import '../../features/tenant/domain/repositories/tenant_repository.dart';
import '../../features/tenant/infrastructure/datasources/tenant_remote_data_source.dart';
import '../../features/tenant/infrastructure/repositories/tenant_repository_impl.dart';
import '../../features/tickets/domain/repositories/ticket_repository.dart';
import '../../features/tickets/domain/usecases/create_ticket_usecase.dart';
import '../../features/tickets/infrastructure/datasources/tickets_remote_data_source.dart';
import '../../features/tickets/infrastructure/repositories/ticket_repository_impl.dart';
import '../network/auth_interceptor.dart';
import '../network/dio_client.dart';
import '../network/tenant_interceptor.dart';
import '../storage/secure_storage_service.dart';
import '../tenant/tenant_code_storage.dart';

/// Application service locator. Kept manual (no injectable codegen) so the
/// wiring is greppable and there is no runtime reflection.
final GetIt sl = GetIt.instance;

class AppEnv {
  const AppEnv({required this.apiBaseUrl});
  final String apiBaseUrl;
}

Future<void> configureDependencies(AppEnv env) async {
  // Storage
  const secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  sl.registerLazySingleton<FlutterSecureStorage>(() => secure);
  sl.registerLazySingleton<SecureStorageService>(
    () => SecureStorageService(sl()),
  );

  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);
  sl.registerLazySingleton<TenantCodeStorage>(() => TenantCodeStorage(sl()));

  // Networking
  sl.registerLazySingleton<TenantInterceptor>(() => TenantInterceptor(sl()));
  // AuthInterceptor needs AuthRemoteDataSource for token refresh — pass a
  // factory instead of a direct instance because the data source depends on
  // Dio which depends on this interceptor (circular). LazySingleton + factory
  // resolves the cycle at first use, after everything is registered.
  sl.registerLazySingleton<AuthInterceptor>(
    () => AuthInterceptor(sl(), () => sl<AuthRemoteDataSource>()),
  );
  sl.registerLazySingleton<Dio>(
    () => DioClient.create(
      baseUrl: env.apiBaseUrl,
      tenantInterceptor: sl(),
      authInterceptor: sl(),
    ),
  );

  // Tenant lookup
  sl.registerLazySingleton<TenantRemoteDataSource>(
    () => TenantRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<TenantRepository>(
    () => TenantRepositoryImpl(sl()),
  );

  // Auth
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remote: sl(), storage: sl()),
  );
  sl.registerFactory<LoginUseCase>(() => LoginUseCase(sl()));

  // Catalog
  sl.registerLazySingleton<CatalogRemoteDataSource>(
    () => CatalogRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<CatalogRepository>(
    () => CatalogRepositoryImpl(sl()),
  );

  // Settings
  sl.registerLazySingleton<SettingsRemoteDataSource>(
    () => SettingsRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(sl()),
  );

  // Staff (barbers)
  sl.registerLazySingleton<StaffRemoteDataSource>(
    () => StaffRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<StaffRepository>(
    () => StaffRepositoryImpl(sl()),
  );

  // Tickets
  sl.registerLazySingleton<TicketsRemoteDataSource>(
    () => TicketsRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<TicketRepository>(
    () => TicketRepositoryImpl(sl()),
  );
  sl.registerFactory<CreateTicketUseCase>(() => CreateTicketUseCase(sl()));

  // Printer
  sl.registerLazySingleton<PrinterService>(
    () => BluetoothThermalPrinterService(sl()),
  );
  sl.registerLazySingleton<PrinterConnectionKeeper>(
    () => PrinterConnectionKeeper(sl()),
  );
}
