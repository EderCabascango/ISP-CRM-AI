import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/wifi_network.dart';
import '../../domain/repositories/wifi_repository.dart';
import '../datasources/wifi_datasource.dart';

class WifiRepositoryImpl implements WifiRepository {
  final WifiDataSource dataSource;

  WifiRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, WifiNetwork>> getWifiSettings() async {
    try {
      final settings = await dataSource.getWifiSettings();
      return Right(settings);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateWifiSettings(WifiNetwork settings) async {
    try {
      await dataSource.updateWifiSettings(settings);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
