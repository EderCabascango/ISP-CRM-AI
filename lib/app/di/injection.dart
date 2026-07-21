import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../features/auth/data/datasources/auth_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/blocs/auth_bloc.dart';

import '../../features/wifi/data/datasources/wifi_datasource.dart';
import '../../features/wifi/data/repositories/wifi_repository_impl.dart';
import '../../features/wifi/domain/repositories/wifi_repository.dart';
import '../../features/wifi/presentation/blocs/wifi_cubit.dart';

import 'package:network_info_plus/network_info_plus.dart';
import '../../features/devices/data/datasources/device_datasource.dart';
import '../../features/devices/data/datasources/device_local_scanner_datasource.dart';
import '../../features/devices/data/repositories/device_repository_impl.dart';
import '../../features/devices/domain/repositories/device_repository.dart';
import '../../features/devices/presentation/blocs/devices_bloc.dart';

final locator = GetIt.instance;

Future<void> initDI() async {
  // Core
  locator.registerLazySingleton<FlutterSecureStorage>(() => const FlutterSecureStorage());
  locator.registerLazySingleton<Dio>(() => Dio());
  locator.registerLazySingleton<ApiClient>(
    () => ApiClient(dio: locator(), secureStorage: locator()),
  );
  locator.registerLazySingleton<NetworkInfo>(() => NetworkInfo());

  // Features - Auth
  locator.registerLazySingleton<AuthDataSource>(() => AuthMockDataSourceImpl());
  locator.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(dataSource: locator()),
  );
  locator.registerFactory(() => AuthBloc(repository: locator()));

  // Features - Wifi
  locator.registerLazySingleton<WifiDataSource>(() => WifiMockDataSourceImpl());
  locator.registerLazySingleton<WifiRepository>(
    () => WifiRepositoryImpl(dataSource: locator()),
  );
  locator.registerFactory(() => WifiCubit(repository: locator()));

  // Features - Devices
  locator.registerLazySingleton<DeviceDataSource>(
    () => DevicesLocalScannerDataSourceImpl(networkInfo: locator()),
  );
  locator.registerLazySingleton<DeviceRepository>(
    () => DeviceRepositoryImpl(dataSource: locator()),
  );
  locator.registerFactory(() => DevicesBloc(repository: locator()));
}
