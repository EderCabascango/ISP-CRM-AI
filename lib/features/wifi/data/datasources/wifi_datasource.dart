import '../../domain/entities/wifi_network.dart';

abstract class WifiDataSource {
  Future<WifiNetwork> getWifiSettings();
  Future<void> updateWifiSettings(WifiNetwork settings);
}

class WifiMockDataSourceImpl implements WifiDataSource {
  WifiNetwork _mockNetwork = const WifiNetwork(
    ssid24: "Fibra_ISP_2.4G",
    password24: "contraseña24G",
    isEnabled24: true,
    ssid50: "Fibra_ISP_5G_Alta_Vel",
    password50: "contraseña50G",
    isEnabled50: true,
  );

  @override
  Future<WifiNetwork> getWifiSettings() async {
    await Future.delayed(const Duration(milliseconds: 600)); // Latencia ficticia
    return _mockNetwork;
  }

  @override
  Future<void> updateWifiSettings(WifiNetwork settings) async {
    await Future.delayed(const Duration(milliseconds: 1000)); // Simula guardado en ONT vía API
    _mockNetwork = settings;
  }
}
