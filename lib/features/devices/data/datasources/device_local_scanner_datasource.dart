import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/connected_device.dart';
import 'device_datasource.dart';
import '../../../../core/error/exceptions.dart';

class DevicesLocalScannerDataSourceImpl implements DeviceDataSource {
  final NetworkInfo networkInfo;

  DevicesLocalScannerDataSourceImpl({required this.networkInfo});

  @override
  Future<List<ConnectedDevice>> getConnectedDevices() async {
    final Stopwatch stopwatch = Stopwatch()..start();
    print('>>> ===================================================');
    print('>>> Iniciando Escaneo Preciso por Sockets (UDP Broadcast + TCP 250ms)...');

    // 1. Validar y solicitar permisos de ubicación
    final permissionStatus = await Permission.location.request();
    if (!permissionStatus.isGranted) {
      print('>>> ERROR: Permisos de ubicación denegados');
      throw PermissionException(
        "Permisos de ubicación denegados. Se requieren para escanear la red Wi-Fi.",
      );
    }

    // 2. Obtener la IP del dispositivo en la red local
    final String? localIp = await networkInfo.getWifiIP();
    print('>>> IP del Celular detectada: $localIp');

    if (localIp == null || localIp.isEmpty || localIp == "0.0.0.0") {
      print('>>> ERROR: No se pudo obtener la IP del Wi-Fi');
      throw PermissionException(
        "No se pudo obtener la IP local. Asegúrate de estar conectado a una red Wi-Fi.",
      );
    }

    // 3. Extraer la subred (Ej: "192.168.1")
    final ipParts = localIp.split('.');
    if (ipParts.length != 4) {
      throw PermissionException("Dirección IP local no válida: $localIp");
    }
    final subnet = "${ipParts[0]}.${ipParts[1]}.${ipParts[2]}";
    print('>>> Subred a explorar: $subnet.1 a $subnet.254');

    // 4. Paquete de activación UDP a NetBIOS (137) y mDNS (5353) para despertar servicios Windows y móviles
    print('>>> Enviando paquetes de activación UDP (NetBIOS 137 / mDNS 5353)...');
    await _sendUdpBroadcast(subnet);

    // Puertos de servicios clave:
    // 135: Windows RPC / NetBIOS
    // 139 / 445: Windows File Sharing / SMB (Incluso con firewall, Windows procesa/responde)
    // 5357: Windows Web Services for Devices (WSD)
    // 80 / 443 / 8080: Web / Router / Smart TV
    // 5353: mDNS Android / Apple / Chromecast
    final List<int> targetPorts = [135, 139, 445, 5357, 80, 443, 5353, 8080];

    // 5. Lanzar escaneo en paralelo para las 254 IPs
    final List<Future<ConnectedDevice?>> scanTasks = [];
    for (int i = 1; i <= 254; i++) {
      final String targetIp = "$subnet.$i";
      scanTasks.add(_scanHost(targetIp, targetPorts, i.toString(), localIp));
    }

    final List<ConnectedDevice?> results = await Future.wait(scanTasks);

    // Filtrar únicamente los dispositivos verdaderamente activos (sin falsos positivos)
    final List<ConnectedDevice> activeDevices = results.whereType<ConnectedDevice>().toList();

    stopwatch.stop();
    final double elapsedSeconds = stopwatch.elapsedMilliseconds / 1000.0;
    print('>>> ===================================================');
    print('>>> ESCANEO COMPLETADO EN ${elapsedSeconds.toStringAsFixed(2)} SEGUNDOS!');
    print('>>> Total de dispositivos reales detectados en la subred: ${activeDevices.length}');
    for (final dev in activeDevices) {
      print('    -> [${dev.ipAddress}] ${dev.name} (MAC: ${dev.macAddress}) - ${dev.interfaceLabel}');
    }
    print('>>> ===================================================');

    return activeDevices;
  }

  // Envía una ráfaga rápida de paquetes UDP a la subred para despertar demonios NetBIOS y mDNS
  Future<void> _sendUdpBroadcast(String subnet) async {
    try {
      final RawDatagramSocket socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final List<int> dummyPacket = [0x00, 0x00, 0x00, 0x00];
      
      for (int i = 1; i <= 254; i++) {
        final target = "$subnet.$i";
        try {
          socket.send(dummyPacket, InternetAddress(target), 137);  // NetBIOS
          socket.send(dummyPacket, InternetAddress(target), 5353); // mDNS
        } catch (_) {}
      }
      await Future.delayed(const Duration(milliseconds: 150));
      socket.close();
    } catch (_) {}
  }

  // Evalúa la presencia real de un host mediante Socket.connect con timeout de 250ms
  Future<ConnectedDevice?> _scanHost(
    String ip,
    List<int> ports,
    String id,
    String localIp,
  ) async {
    // Si es este mismo celular
    if (ip == localIp) {
      return ConnectedDevice(
        id: id,
        name: "Este Teléfono (Android)",
        ipAddress: ip,
        macAddress: "02:00:00:00:00:LOCAL",
        isOnline: true,
        interfaceType: DeviceInterfaceType.wifi50,
        interfaceLabel: "Este Dispositivo",
      );
    }

    bool isAlive = false;
    String statusReason = "";

    for (final port in ports) {
      try {
        final Socket socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 250), // Timeout de 250ms
        );
        socket.destroy();
        isAlive = true;
        statusReason = "Puerto $port Abierto";
        break; // Conexión completada exitosamente
      } on SocketException catch (e) {
        final String msg = e.message.toLowerCase();
        final String errStr = e.toString().toLowerCase();

        // Eliminar falsos positivos (Host unreachable / no route / error 111 / error 113)
        final bool isUnreachable = msg.contains('unreachable') ||
            msg.contains('no route') ||
            errStr.contains('113');

        // Unicamente considerar activo si el host de destino rehusó explícitamente la conexión TCP
        if (!isUnreachable && (msg.contains('refused') || msg.contains('reset'))) {
          isAlive = true;
          statusReason = "Rechazo Explícito en Puerto $port";
          break;
        }
      } catch (_) {
        // Ignorar timeouts
      }
    }

    if (isAlive) {
      print('>>> DISPOSITIVO RECONOCIDO: $ip ($statusReason)');

      String name = "Dispositivo de Red";
      if (ip.endsWith('.1')) {
        name = "Router / Gateway Principal";
      } else {
        try {
          final List<InternetAddress> addresses = await InternetAddress.lookup(ip)
              .timeout(const Duration(milliseconds: 150));
          if (addresses.isNotEmpty && addresses.first.host != ip) {
            name = addresses.first.host;
          } else {
            name = "Equipo ($ip)";
          }
        } catch (_) {
          name = "Equipo ($ip)";
        }
      }

      final String hostHex = int.parse(ip.split('.').last).toRadixString(16).padLeft(2, '0').toUpperCase();
      final String macAddress = "02:00:00:00:00:$hostHex";

      return ConnectedDevice(
        id: id,
        name: name,
        ipAddress: ip,
        macAddress: macAddress,
        isOnline: true,
        interfaceType: DeviceInterfaceType.wifi24,
        interfaceLabel: "Wi-Fi ($statusReason)",
      );
    }

    return null;
  }
}
