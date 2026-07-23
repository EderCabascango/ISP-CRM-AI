import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/wifi_credentials_payload.dart';

abstract class WifiManagementRepository {
  Future<Either<Failure, void>> updateWifiCredentials(
    WifiCredentialsPayload payload,
  );
}
