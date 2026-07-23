import 'package:equatable/equatable.dart';
import '../../data/services/network_health_checker.dart';

abstract class NetworkHealthState extends Equatable {
  const NetworkHealthState();

  @override
  List<Object?> get props => [];
}

class NetworkHealthInitial extends NetworkHealthState {
  const NetworkHealthInitial();
}

class NetworkHealthLoading extends NetworkHealthState {
  const NetworkHealthLoading();
}

class NetworkHealthSuccess extends NetworkHealthState {
  final NetworkHealthResult result;

  const NetworkHealthSuccess(this.result);

  @override
  List<Object?> get props => [result];
}

class NetworkHealthNoWifi extends NetworkHealthState {
  final String message;

  const NetworkHealthNoWifi(this.message);

  @override
  List<Object?> get props => [message];
}

class NetworkHealthError extends NetworkHealthState {
  final String errorMessage;

  const NetworkHealthError(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
