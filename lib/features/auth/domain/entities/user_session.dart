import 'package:equatable/equatable.dart';

class UserSession extends Equatable {
  final String contractNumber;
  final String token;
  final String clientName;

  const UserSession({
    required this.contractNumber,
    required this.token,
    required this.clientName,
  });

  @override
  List<Object?> get props => [contractNumber, token, clientName];
}
