import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_session.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserSession>> login(String contractNumber);
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, UserSession?>> getCachedSession();
}
