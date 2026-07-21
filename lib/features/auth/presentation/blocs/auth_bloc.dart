import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';

// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class CheckAuthSessionEvent extends AuthEvent {}

class LoginSubmittedEvent extends AuthEvent {
  final String contractNumber;
  const LoginSubmittedEvent(this.contractNumber);
  @override
  List<Object?> get props => [contractNumber];
}

class LogoutRequestedEvent extends AuthEvent {}

// States
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitialState extends AuthState {}

class AuthLoadingState extends AuthState {}

class AuthenticatedState extends AuthState {
  final UserSession session;
  const AuthenticatedState(this.session);
  @override
  List<Object?> get props => [session];
}

class UnauthenticatedState extends AuthState {
  final String? errorMessage;
  const UnauthenticatedState({this.errorMessage});
  @override
  List<Object?> get props => [errorMessage];
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository repository;

  AuthBloc({required this.repository}) : super(AuthInitialState()) {
    on<CheckAuthSessionEvent>((event, emit) async {
      emit(AuthLoadingState());
      final result = await repository.getCachedSession();
      result.fold(
        (failure) => emit(const UnauthenticatedState()),
        (session) {
          if (session != null) {
            emit(AuthenticatedState(session));
          } else {
            emit(const UnauthenticatedState());
          }
        },
      );
    });

    on<LoginSubmittedEvent>((event, emit) async {
      emit(AuthLoadingState());
      final result = await repository.login(event.contractNumber);
      result.fold(
        (failure) => emit(UnauthenticatedState(errorMessage: failure.message)),
        (session) => emit(AuthenticatedState(session)),
      );
    });

    on<LogoutRequestedEvent>((event, emit) async {
      emit(AuthLoadingState());
      await repository.logout();
      emit(const UnauthenticatedState());
    });
  }
}
