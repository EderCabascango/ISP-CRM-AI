import 'package:flutter_test/flutter_test.dart';
import 'package:isp_app/app/di/injection.dart';
import 'package:isp_app/features/auth/data/datasources/auth_datasource.dart';
import 'package:isp_app/features/wifi/data/datasources/wifi_datasource.dart';
import 'package:isp_app/features/devices/data/datasources/device_datasource.dart';

void main() {
  test('Verificar registro de DI inicial', () async {
    // Inicializa la inyección de dependencias
    await initDI();
    
    // Verifica que las dependencias requeridas estén registradas
    expect(locator.isRegistered<AuthDataSource>(), true);
    expect(locator.isRegistered<WifiDataSource>(), true);
    expect(locator.isRegistered<DeviceDataSource>(), true);
  });
}
