import '../../domain/entities/user_session.dart';
import '../../../../core/error/exceptions.dart';

abstract class AuthDataSource {
  Future<UserSession> login(String contractNumber);
  Future<void> saveSession(UserSession session);
  Future<UserSession?> getCachedSession();
  Future<void> deleteSession();
}

class AuthMockDataSourceImpl implements AuthDataSource {
  UserSession? _cachedSession;

  @override
  Future<UserSession> login(String contractNumber) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Simula latencia
    if (contractNumber.trim().isEmpty) {
      throw AuthException("El número de contrato no puede estar vacío");
    }
    // Aceptamos cualquier número de contrato para simulación, por ejemplo "12345"
    return UserSession(
      contractNumber: contractNumber,
      token: "mock-jwt-token-xyz-123456789",
      clientName: "Juan Pérez (Abonado ISP)",
    );
  }

  @override
  Future<void> saveSession(UserSession session) async {
    _cachedSession = session;
  }

  @override
  Future<UserSession?> getCachedSession() async {
    return _cachedSession;
  }

  @override
  Future<void> deleteSession() async {
    _cachedSession = null;
  }
}
