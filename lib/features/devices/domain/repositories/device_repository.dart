import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/connected_device.dart';

abstract class DeviceRepository {
  Future<Either<Failure, List<ConnectedDevice>>> getConnectedDevices();
}
