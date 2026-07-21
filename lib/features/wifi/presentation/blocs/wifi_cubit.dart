import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/wifi_network.dart';
import '../../domain/repositories/wifi_repository.dart';

abstract class WifiState extends Equatable {
  const WifiState();
  @override
  List<Object?> get props => [];
}

class WifiInitialState extends WifiState {}

class WifiLoadingState extends WifiState {}

class WifiLoadSuccessState extends WifiState {
  final WifiNetwork network;
  const WifiLoadSuccessState(this.network);
  @override
  List<Object?> get props => [network];
}

class WifiSubmittingState extends WifiState {}

class WifiSubmitSuccessState extends WifiState {
  final WifiNetwork network;
  const WifiSubmitSuccessState(this.network);
  @override
  List<Object?> get props => [network];
}

class WifiFailureState extends WifiState {
  final String errorMessage;
  const WifiFailureState(this.errorMessage);
  @override
  List<Object?> get props => [errorMessage];
}

class WifiCubit extends Cubit<WifiState> {
  final WifiRepository repository;

  WifiCubit({required this.repository}) : super(WifiInitialState());

  Future<void> loadSettings() async {
    emit(WifiLoadingState());
    final result = await repository.getWifiSettings();
    result.fold(
      (failure) => emit(WifiFailureState(failure.message)),
      (network) => emit(WifiLoadSuccessState(network)),
    );
  }

  Future<void> updateSettings(WifiNetwork settings) async {
    emit(WifiSubmittingState());
    final result = await repository.updateWifiSettings(settings);
    result.fold(
      (failure) => emit(WifiFailureState(failure.message)),
      (_) => emit(WifiSubmitSuccessState(settings)),
    );
  }
}
