import '../../domain/entities/connected_device.dart';

abstract class DeviceDataSource {
  Future<List<ConnectedDevice>> getConnectedDevices();
}

class DeviceMockDataSourceImpl implements DeviceDataSource {
  @override
  Future<List<ConnectedDevice>> getConnectedDevices() async {
    await Future.delayed(const Duration(milliseconds: 700)); // Latencia ficticia
    return [
      const ConnectedDevice(
        id: "1",
        name: "iPhone 15 Pro Max",
        ipAddress: "192.168.100.12",
        macAddress: "AA:BB:CC:DD:EE:01",
        isOnline: true,
        interfaceType: DeviceInterfaceType.wifi50,
        interfaceLabel: "Wi-Fi 5GHz",
      ),
      const ConnectedDevice(
        id: "2",
        name: "Smart TV LG OLED",
        ipAddress: "192.168.100.25",
        macAddress: "AA:BB:CC:DD:EE:02",
        isOnline: true,
        interfaceType: DeviceInterfaceType.lan,
        interfaceLabel: "Puerto LAN 1",
      ),
      const ConnectedDevice(
        id: "3",
        name: "PlayStation 5",
        ipAddress: "192.168.100.30",
        macAddress: "AA:BB:CC:DD:EE:03",
        isOnline: true,
        interfaceType: DeviceInterfaceType.lan,
        interfaceLabel: "Puerto LAN 2",
      ),
      const ConnectedDevice(
        id: "4",
        name: "Xiaomi Redmi Note 12",
        ipAddress: "192.168.100.41",
        macAddress: "AA:BB:CC:DD:EE:04",
        isOnline: true,
        interfaceType: DeviceInterfaceType.wifi24,
        interfaceLabel: "Wi-Fi 2.4GHz",
      ),
      const ConnectedDevice(
        id: "5",
        name: "MacBook Pro M3",
        ipAddress: "192.168.100.15",
        macAddress: "AA:BB:CC:DD:EE:05",
        isOnline: false,
        interfaceType: DeviceInterfaceType.wifi50,
        interfaceLabel: "Wi-Fi 5GHz",
      ),
    ];
  }
}
