import 'package:equatable/equatable.dart';

abstract class WifiFormState extends Equatable {
  const WifiFormState();

  @override
  List<Object?> get props => [];
}

class WifiFormInitial extends WifiFormState {
  const WifiFormInitial();
}

class WifiFormLoading extends WifiFormState {
  const WifiFormLoading();
}

class WifiFormSuccess extends WifiFormState {
  final String message;

  const WifiFormSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class WifiFormError extends WifiFormState {
  final String errorMessage;

  const WifiFormError(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
