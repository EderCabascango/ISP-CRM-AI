import 'package:equatable/equatable.dart';

enum DeviceInterfaceType { wifi24, wifi50, lan }

class ConnectedDevice extends Equatable {
  final String id;
  final String name;
  final String ipAddress;
  final String macAddress;
  final bool isOnline;
  final DeviceInterfaceType interfaceType;
  final String interfaceLabel; // Ej. "Puerto LAN 1", "Wi-Fi 5GHz"

  const ConnectedDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.macAddress,
    required this.isOnline,
    required this.interfaceType,
    required this.interfaceLabel,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        ipAddress,
        macAddress,
        isOnline,
        interfaceType,
        interfaceLabel,
      ];
}
