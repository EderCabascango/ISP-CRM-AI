import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/connected_device.dart';
import '../repositories/connected_devices_repository_impl.dart';

abstract class DevicesState extends Equatable {
  const DevicesState();
  @override
  List<Object?> get props => [];
}

class DevicesInitialState extends DevicesState {
  const DevicesInitialState();
}

class DevicesLoadingState extends DevicesState {
  const DevicesLoadingState();
}

class DevicesLoadedState extends DevicesState {
  final List<ConnectedDevice> devices;
  const DevicesLoadedState(this.devices);
  @override
  List<Object?> get props => [devices];
}

class DevicesErrorState extends DevicesState {
  final String message;
  const DevicesErrorState(this.message);
  @override
  List<Object?> get props => [message];
}

class ConnectedDevicesCubit extends Cubit<DevicesState> {
  final ConnectedDevicesRepository repository;

  ConnectedDevicesCubit({required this.repository}) : super(const DevicesInitialState());

  Future<void> fetchDevices() async {
    emit(const DevicesLoadingState());
    final result = await repository.getConnectedDevices();
    result.fold(
      (failure) => emit(DevicesErrorState(failure.message)),
      (devices) => emit(DevicesLoadedState(devices)),
    );
  }

  Future<void> toggleBlock(String macAddress, bool currentBlockState) async {
    if (state is DevicesLoadedState) {
      final currentList = (state as DevicesLoadedState).devices;
      final updatedList = currentList.map((dev) {
        if (dev.macAddress == macAddress) {
          return ConnectedDevice(
            ipAddress: dev.ipAddress,
            macAddress: dev.macAddress,
            hostname: dev.hostname,
            connectionType: dev.connectionType,
            signalStrength: dev.signalStrength,
            isBlocked: !currentBlockState,
          );
        }
        return dev;
      }).toList();

      emit(DevicesLoadedState(updatedList));

      final result = await repository.toggleBlockDevice(macAddress, !currentBlockState);
      result.fold(
        (failure) {
          // Revertir si falló
          emit(DevicesLoadedState(currentList));
        },
        (_) {},
      );
    }
  }
}
