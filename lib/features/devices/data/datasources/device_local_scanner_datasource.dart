import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/connected_device.dart';
import 'device_datasource.dart';
import '../../../../core/error/exceptions.dart';

// Paquete M-SEARCH SSDP/UPnP estándar (RFC 2616) — Windows, Smart TVs, Routers responden a esto
const List<int> _ssdpMSearch = [
  0x4d, 0x2d, 0x53, 0x45, 0x41, 0x52, 0x43, 0x48, 0x20, 0x2a, 0x20,
  0x48, 0x54, 0x54, 0x50, 0x2f, 0x31, 0x2e, 0x31, 0x0d, 0x0a,
  0x48, 0x4f, 0x53, 0x54, 0x3a, 0x20, 0x32, 0x33, 0x39, 0x2e,
  0x32, 0x35, 0x35, 0x2e, 0x32, 0x35, 0x35, 0x32, 0x35, 0x30,
  0x3a, 0x31, 0x39, 0x30, 0x30, 0x0d, 0x0a,
  0x4d, 0x41, 0x4e, 0x3a, 0x20, 0x22, 0x73, 0x73, 0x64, 0x70,
  0x3a, 0x64, 0x69, 0x73, 0x63, 0x6f, 0x76, 0x65, 0x72, 0x22,
  0x0d, 0x0a,
  0x4d, 0x58, 0x3a, 0x20, 0x33, 0x0d, 0x0a,
  0x53, 0x54, 0x3a, 0x20, 0x73, 0x73, 0x64, 0x70, 0x3a, 0x61,
  0x6c, 0x6c, 0x0d, 0x0a, 0x0d, 0x0a,
];

// Query de nombre NetBIOS (RFC 1002) — todas las PCs Windows responden con su nombre de equipo
const List<int> _netbiosNameQuery = [
  0x82, 0x28, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x20, 0x43, 0x4b, 0x41, 0x41, 0x41, 0x41, 0x41,
  0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
  0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
  0x41, 0x41, 0x41, 0x41, 0x41, 0x00, 0x00, 0x21, 0x00, 0x01,
];

class DevicesLocalScannerDataSourceImpl implements DeviceDataSource {
  final NetworkInfo networkInfo;

  DevicesLocalScannerDataSourceImpl({required this.networkInfo});

  @override
  Future<List<ConnectedDevice>> getConnectedDevices() async {
    final Stopwatch stopwatch = Stopwatch()..start();
    print('>>> ===================================================');
    print('>>> Iniciando Escaneo Híbrido: UDP Broadcast + TCP Paralelo...');

    // 1. Permisos de ubicación (requeridos por Android para leer IP Wi-Fi)
    final permissionStatus = await Permission.location.request();
    if (!permissionStatus.isGranted) {
      print('>>> ERROR: Permisos de ubicación denegados');
      throw PermissionException(
        "Permisos de ubicación denegados. Se requieren para escanear la red Wi-Fi.",
      );
    }

    // 2. IP local del dispositivo
    final String? localIp = await networkInfo.getWifiIP();
    print('>>> IP del Celular detectada: $localIp');

    if (localIp == null || localIp.isEmpty || localIp == "0.0.0.0") {
      print('>>> ERROR: No se pudo obtener la IP del Wi-Fi');
      throw PermissionException(
        "No se pudo obtener la IP local. Asegúrate de estar conectado a una red Wi-Fi.",
      );
    }

    final ipParts = localIp.split('.');
    if (ipParts.length != 4) {
      throw PermissionException("Dirección IP local no válida: $localIp");
    }
    final subnet = "${ipParts[0]}.${ipParts[1]}.${ipParts[2]}";
    final broadcastIp = "$subnet.255";
    print('>>> Subred: $subnet.1–$subnet.254  |  Broadcast: $broadcastIp');

    // Mapa compartido de resultados (IP → ConnectedDevice)
    // Se alimenta tanto por UDP como por TCP
    final Map<String, ConnectedDevice> discovered = {};

    // ─────────────────────────────────────────────────
    // FASE 1: UDP BROADCAST — SSDP/UPnP + NetBIOS + mDNS
    // Escucha respuestas durante 500ms mientras los enviamos
    // ─────────────────────────────────────────────────
    print('>>> [FASE 1 - UDP] Enviando broadcasts SSDP (1900) + NetBIOS (137) + mDNS (5353)...');
    final Map<String, String> udpDiscovered = await _udpBroadcastDiscovery(
      subnet: subnet,
      broadcastIp: broadcastIp,
      localIp: localIp,
    );

    for (final entry in udpDiscovered.entries) {
      final ip = entry.key;
      final protocol = entry.value;
      print('>>> [UDP] DISPOSITIVO VIA BROADCAST: $ip (Protocolo: $protocol)');
      discovered[ip] = _buildDevice(ip, ip, ip == localIp ? "Este Teléfono (Android)" : null, protocol, localIp);
    }
    print('>>> [FASE 1 - UDP] Dispositivos encontrados por broadcast: ${udpDiscovered.length}');

    // ─────────────────────────────────────────────────
    // FASE 2: TCP SOCKET PARALELO — 254 IPs simultáneas
    // Puertos Windows: 135 (RPC), 139 (NetBIOS/SMB), 445 (SMB), 5357 (WSD), 2869 (UPnP)
    // Puertos Web/IoT: 80, 443, 8080
    // Puertos Discovery: 5353 (mDNS)
    // ─────────────────────────────────────────────────
    final List<int> tcpPorts = [135, 139, 445, 5357, 2869, 80, 443, 5353, 8080];
    print('>>> [FASE 2 - TCP] Escaneando $subnet.1–$subnet.254 en paralelo (timeout 250ms)...');
    print('>>> [FASE 2 - TCP] Puertos: ${tcpPorts.join(', ')}');

    final List<Future<MapEntry<String, String>?>> tcpTasks = [];
    for (int i = 1; i <= 254; i++) {
      final String targetIp = "$subnet.$i";
      tcpTasks.add(_tcpProbeHost(targetIp, tcpPorts, localIp));
    }

    final List<MapEntry<String, String>?> tcpResults = await Future.wait(tcpTasks);

    for (final entry in tcpResults) {
      if (entry == null) continue;
      final ip = entry.key;
      final reason = entry.value;
      if (!discovered.containsKey(ip)) {
        print('>>> [TCP] DISPOSITIVO VIA SOCKET: $ip ($reason)');
        discovered[ip] = _buildDevice(ip, ip, null, reason, localIp);
      } else {
        // Ya detectado por UDP — actualizar el método de detección
        print('>>> [TCP+UDP] Confirmado: $ip ($reason)');
      }
    }

    // Agregar el propio teléfono si no fue encontrado aún
    if (!discovered.containsKey(localIp)) {
      discovered[localIp] = _buildDevice(localIp, localIp, "Este Teléfono (Android)", "Este Dispositivo", localIp);
    }

    final List<ConnectedDevice> activeDevices = discovered.values.toList();

    stopwatch.stop();
    final double elapsedSeconds = stopwatch.elapsedMilliseconds / 1000.0;
    print('>>> ===================================================');
    print('>>> ESCANEO COMPLETADO EN ${elapsedSeconds.toStringAsFixed(2)} SEGUNDOS!');
    print('>>> Dispositivos únicos detectados: ${activeDevices.length}');
    for (final dev in activeDevices) {
      print('    -> [${dev.ipAddress}] ${dev.name} - ${dev.interfaceLabel}');
    }
    print('>>> ===================================================');

    return activeDevices;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FASE 1: UDP BROADCAST — escucha respuestas durante 500ms
  // Envía: SSDP M-SEARCH (1900) → broadcast, NetBIOS (137) → unicast, mDNS (5353) → multicast
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, String>> _udpBroadcastDiscovery({
    required String subnet,
    required String broadcastIp,
    required String localIp,
  }) async {
    final Map<String, String> found = {};

    try {
      // Socket con permiso de broadcast habilitado
      final RawDatagramSocket socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;

      // ── Enviar SSDP M-SEARCH al broadcast de la subred (UPnP/Windows/Smart TV/Routers)
      try {
        socket.send(_ssdpMSearch, InternetAddress(broadcastIp), 1900);
        socket.send(_ssdpMSearch, InternetAddress('239.255.255.250'), 1900); // Multicast SSDP
      } catch (_) {}

      // ── Enviar NetBIOS Name Query a cada IP de la subred (unicast para mayor respuesta)
      for (int i = 1; i <= 254; i++) {
        final target = "$subnet.$i";
        if (target == localIp) continue;
        try {
          socket.send(_netbiosNameQuery, InternetAddress(target), 137);
        } catch (_) {}
      }

      // ── Enviar mDNS query al multicast estándar
      final List<int> mdnsQuery = [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x05, 0x5f, 0x68, 0x74,
        0x74, 0x70, 0x04, 0x5f, 0x74, 0x63, 0x70, 0x05,
        0x6c, 0x6f, 0x63, 0x61, 0x6c, 0x00, 0x00, 0x0c,
        0x00, 0x01,
      ];
      try {
        socket.send(mdnsQuery, InternetAddress('224.0.0.251'), 5353);
      } catch (_) {}

      // ── Escuchar respuestas durante 500ms
      final Completer<void> completer = Completer();
      final Timer timer = Timer(const Duration(milliseconds: 500), () {
        if (!completer.isCompleted) completer.complete();
      });

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final Datagram? dg = socket.receive();
          if (dg != null) {
            final String senderIp = dg.address.address;
            // Ignorar nuestra propia IP y broadcasts
            if (senderIp != localIp &&
                senderIp.startsWith(subnet) &&
                !senderIp.endsWith('.255') &&
                !found.containsKey(senderIp)) {
              // Determinar protocolo por puerto de destino (dg.port es origen, pero el contexto lo aclara)
              String protocol = 'UDP Response';
              if (dg.port == 1900 || dg.port == 1901) {
                protocol = 'SSDP/UPnP (Puerto 1900)';
              } else if (dg.port == 137 || dg.port == 138) {
                protocol = 'NetBIOS (Puerto 137)';
              } else if (dg.port == 5353) {
                protocol = 'mDNS (Puerto 5353)';
              }
              found[senderIp] = protocol;
            }
          }
        }
      });

      await completer.future;
      timer.cancel();
      socket.close();
    } catch (_) {}

    return found;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FASE 2: TCP PROBE — intenta conexión a cada IP en los puertos dados
  // Marca como activo si: (a) conexión exitosa, o (b) rechazo explícito del host destino
  // ─────────────────────────────────────────────────────────────────────────
  Future<MapEntry<String, String>?> _tcpProbeHost(
    String ip,
    List<int> ports,
    String localIp,
  ) async {
    if (ip == localIp) {
      return MapEntry(ip, 'Este Dispositivo');
    }

    for (final port in ports) {
      try {
        final Socket socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 250),
        );
        socket.destroy();
        return MapEntry(ip, _portLabel(port, 'Abierto'));
      } on SocketException catch (e) {
        final String msg = e.message.toLowerCase();
        final String errStr = e.toString().toLowerCase();

        // Eliminar falsos positivos: respuestas del router (ICMP Unreachable = IP no existe)
        final bool isUnreachable = msg.contains('unreachable') ||
            msg.contains('no route') ||
            errStr.contains('113');

        // Solo marcar activo si el HOST DESTINO rechazó explícitamente (TCP RST/FIN)
        if (!isUnreachable && (msg.contains('refused') || msg.contains('reset'))) {
          return MapEntry(ip, _portLabel(port, 'RST'));
        }
      } catch (_) {
        // Timeout u otro error de red — continuar con siguiente puerto
      }
    }
    return null;
  }

  // Construye la entidad ConnectedDevice con nombre, MAC sintético e interfaz correcta
  ConnectedDevice _buildDevice(
    String id,
    String ip,
    String? forcedName,
    String detectionReason,
    String localIp,
  ) {
    String name = forcedName ?? _guessName(ip);
    if (name == ip) {
      // Intentar resolución DNS inversa (best-effort)
      // No esperamos el Future aquí porque ya estamos dentro de un mapa síncrono
      name = "Equipo ($ip)";
    }

    final bool isSelf = ip == localIp;
    final String hostHex = int.parse(ip.split('.').last).toRadixString(16).padLeft(2, '0').toUpperCase();
    final String mac = isSelf ? "02:00:00:00:00:LOCAL" : "02:00:00:00:00:$hostHex";

    return ConnectedDevice(
      id: ip.split('.').last,
      name: name,
      ipAddress: ip,
      macAddress: mac,
      isOnline: true,
      interfaceType: isSelf ? DeviceInterfaceType.wifi50 : DeviceInterfaceType.wifi24,
      interfaceLabel: detectionReason,
    );
  }

  String _guessName(String ip) {
    if (ip.endsWith('.1')) return 'Router / Gateway Principal';
    return ip;
  }

  String _portLabel(int port, String status) {
    switch (port) {
      case 135:
        return 'Windows RPC/DCE (Puerto 135 $status)';
      case 139:
        return 'NetBIOS/SMB (Puerto 139 $status)';
      case 445:
        return 'SMB / Compartir Archivos (Puerto 445 $status)';
      case 5357:
        return 'WSD Windows (Puerto 5357 $status)';
      case 2869:
        return 'UPnP Eventing (Puerto 2869 $status)';
      case 5353:
        return 'mDNS Android/iOS (Puerto 5353 $status)';
      case 80:
        return 'HTTP Web (Puerto 80 $status)';
      case 443:
        return 'HTTPS (Puerto 443 $status)';
      case 8080:
        return 'HTTP Alternativo (Puerto 8080 $status)';
      default:
        return 'Puerto $port $status';
    }
  }
}
