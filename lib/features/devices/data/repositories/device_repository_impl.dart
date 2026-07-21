import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/connected_device.dart';
import '../../domain/repositories/device_repository.dart';
import '../datasources/device_datasource.dart';

import '../../../../core/error/exceptions.dart';

class DeviceRepositoryImpl implements DeviceRepository {
  final DeviceDataSource dataSource;

  DeviceRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, List<ConnectedDevice>>> getConnectedDevices() async {
    try {
      final devices = await dataSource.getConnectedDevices();
      return Right(devices);
    } on PermissionException catch (e) {
      return Left(PermissionFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
