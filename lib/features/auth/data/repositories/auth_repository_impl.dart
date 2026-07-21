import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDataSource dataSource;

  AuthRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, UserSession>> login(String contractNumber) async {
    try {
      final session = await dataSource.login(contractNumber);
      await dataSource.saveSession(session);
      return Right(session);
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await dataSource.deleteSession();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserSession?>> getCachedSession() async {
    try {
      final session = await dataSource.getCachedSession();
      return Right(session);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
