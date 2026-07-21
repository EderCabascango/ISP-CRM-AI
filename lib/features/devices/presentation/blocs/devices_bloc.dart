import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/connected_device.dart';
import '../../domain/repositories/device_repository.dart';

// Events
abstract class DevicesEvent extends Equatable {
  const DevicesEvent();
  @override
  List<Object?> get props => [];
}

class FetchDevicesEvent extends DevicesEvent {}

enum DeviceFilter { all, wifi, lan }

class ChangeFilterEvent extends DevicesEvent {
  final DeviceFilter filter;
  const ChangeFilterEvent(this.filter);
  @override
  List<Object?> get props => [filter];
}

// States
abstract class DevicesState extends Equatable {
  const DevicesState();
  @override
  List<Object?> get props => [];
}

class DevicesInitialState extends DevicesState {}

class DevicesLoadingState extends DevicesState {}

class DevicesLoadSuccessState extends DevicesState {
  final List<ConnectedDevice> allDevices;
  final List<ConnectedDevice> filteredDevices;
  final DeviceFilter activeFilter;

  const DevicesLoadSuccessState({
    required this.allDevices,
    required this.filteredDevices,
    required this.activeFilter,
  });

  @override
  List<Object?> get props => [allDevices, filteredDevices, activeFilter];
}

class DevicesFailureState extends DevicesState {
  final String errorMessage;
  const DevicesFailureState(this.errorMessage);
  @override
  List<Object?> get props => [errorMessage];
}

// BLoC
class DevicesBloc extends Bloc<DevicesEvent, DevicesState> {
  final DeviceRepository repository;

  DevicesBloc({required this.repository}) : super(DevicesInitialState()) {
    on<FetchDevicesEvent>((event, emit) async {
      emit(DevicesLoadingState());
      final result = await repository.getConnectedDevices();
      result.fold(
        (failure) => emit(DevicesFailureState(failure.message)),
        (devices) => emit(DevicesLoadSuccessState(
          allDevices: devices,
          filteredDevices: devices,
          activeFilter: DeviceFilter.all,
        )),
      );
    });

    on<ChangeFilterEvent>((event, emit) {
      final currentState = state;
      if (currentState is DevicesLoadSuccessState) {
        List<ConnectedDevice> filtered;
        switch (event.filter) {
          case DeviceFilter.wifi:
            filtered = currentState.allDevices
                .where((d) =>
                    d.interfaceType == DeviceInterfaceType.wifi24 ||
                    d.interfaceType == DeviceInterfaceType.wifi50)
                .toList();
            break;
          case DeviceFilter.lan:
            filtered = currentState.allDevices
                .where((d) => d.interfaceType == DeviceInterfaceType.lan)
                .toList();
            break;
          case DeviceFilter.all:
            filtered = currentState.allDevices;
            break;
        }
        emit(DevicesLoadSuccessState(
          allDevices: currentState.allDevices,
          filteredDevices: filtered,
          activeFilter: event.filter,
        ));
      }
    });
  }
}
