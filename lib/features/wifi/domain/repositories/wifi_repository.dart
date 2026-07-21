import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/wifi_network.dart';

abstract class WifiRepository {
  Future<Either<Failure, WifiNetwork>> getWifiSettings();
  Future<Either<Failure, void>> updateWifiSettings(WifiNetwork settings);
}
