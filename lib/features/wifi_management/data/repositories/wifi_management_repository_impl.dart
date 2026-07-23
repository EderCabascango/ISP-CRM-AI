import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../models/wifi_credentials_payload.dart';
import '../../domain/repositories/wifi_management_repository.dart';

class WifiManagementRepositoryImpl implements WifiManagementRepository {
  final Dio dio;
  final FlutterSecureStorage secureStorage;

  WifiManagementRepositoryImpl({
    required this.dio,
    required this.secureStorage,
  });

  @override
  Future<Either<Failure, void>> updateWifiCredentials(
    WifiCredentialsPayload payload,
  ) async {
    try {
      final token = await secureStorage.read(key: 'auth_token');
      
      final response = await dio.post(
        '/api/v1/router/wifi-credentials',
        data: payload.toJson(),
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return const Right(null);
      } else {
        final message = response.data?['message'] ?? 'Error al actualizar credenciales Wi-Fi.';
        return Left(ServerFailure(message));
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data?['message'] ??
          e.message ??
          'No se pudo conectar con el servidor del router.';
      return Left(ServerFailure(errorMessage));
    } catch (e) {
      return Left(ServerFailure('Ocurrió un error inesperado: ${e.toString()}'));
    }
  }
}
