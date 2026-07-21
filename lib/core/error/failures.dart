import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = "Error en el servidor"]);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = "Sin conexión a internet"]);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = "Error de caché"]);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = "Credenciales incorrectas"]);
}

class PermissionFailure extends Failure {
  const PermissionFailure([super.message = "Permisos denegados para realizar la acción"]);
}
