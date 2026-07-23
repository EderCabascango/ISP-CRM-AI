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

// Query de nombre NetBIOS (RFC 1002) — PCs Windows responden con su nombre de equipo
const List<int> _netbiosNameQuery = [
  0x82, 0x28, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x20, 0x43, 0x4b, 0x41, 0x41, 0x41, 0x41, 0x41,
  0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
  0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
  0x41, 0x41, 0x41, 0x41, 0x41, 0x00, 0x00, 0x21, 0x00, 0x01,
];

// Paquete UDP mínimo para forzar resolución ARP en el kernel de Android
const List<int> _arpKickPacket = [0x00, 0x00, 0x00, 0x00];

class DevicesLocalScannerDataSourceImpl implements DeviceDataSource {
  final NetworkInfo networkInfo;

  DevicesLocalScannerDataSourceImpl({required this.networkInfo});

  @override
  Future<List<ConnectedDevice>> getConnectedDevices() async {
    final Stopwatch stopwatch = Stopwatch()..start();
    print('>>> ===================================================');
    print('>>> Iniciando Escaneo 4 Fases: ARP Kick + ARP Read + UDP Broadcast + TCP...');

    // 1. Permisos de ubicación (Android los requiere para leer IP Wi-Fi)
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

    // Mapa compartido IP → ConnectedDevice (deduplicación automática)
    final Map<String, ConnectedDevice> discovered = {};

    // ═══════════════════════════════════════════════════════════════
    // FASE 0: ARP KICK — Ráfaga UDP a todas las IPs para forzar al
    //         kernel de Android a resolver la MAC de cada IP (ARP).
    //         Esto popula /proc/net/arp ANTES de leerlo.
    // ═══════════════════════════════════════════════════════════════
    print('>>> [FASE 0 - ARP KICK] Enviando ráfaga UDP a $subnet.1–$subnet.254 para poblar tabla ARP...');
    await _arpKickSpray(subnet, localIp);
    // Pausa crítica: dar tiempo al kernel Android para registrar las MACs en la tabla ARP
    await Future.delayed(const Duration(milliseconds: 300));

    // ═══════════════════════════════════════════════════════════════
    // FASE 1: ARP TABLE READ — Leer /proc/net/arp o ejecutar `ip neigh`
    //         para obtener IPs que respondieron a nivel de capa 2 (MAC).
    //         Estos dispositivos son REALES aunque tengan todos los puertos cerrados.
    // ═══════════════════════════════════════════════════════════════
    print('>>> [FASE 1 - ARP] Leyendo tabla ARP del kernel (/proc/net/arp + ip neigh)...');
    final Map<String, String> arpEntries = await _readArpTable(subnet, localIp);
    print('>>> [FASE 1 - ARP] Entradas ARP válidas encontradas: ${arpEntries.length} → ${arpEntries.keys.toList()}');

    for (final entry in arpEntries.entries) {
      final ip = entry.key;
      final mac = entry.value;
      if (!discovered.containsKey(ip)) {
        print('>>> [ARP] DISPOSITIVO VIA TABLA ARP: $ip (MAC: $mac)');
        discovered[ip] = ConnectedDevice(
          id: ip.split('.').last,
          name: _guessName(ip),
          ipAddress: ip,
          macAddress: mac,
          isOnline: true,
          interfaceType: DeviceInterfaceType.wifi24,
          interfaceLabel: 'ARP (MAC: $mac)',
        );
      }
    }

    // ═══════════════════════════════════════════════════════════════
    // FASE 2: UDP BROADCAST — SSDP/UPnP + NetBIOS + mDNS
    //         Escucha respuestas durante 500ms.
    //         Funciona para dispositivos en LAN y Wi-Fi que anuncian presencia.
    // ═══════════════════════════════════════════════════════════════
    print('>>> [FASE 2 - UDP] Enviando broadcasts SSDP (1900) + NetBIOS (137) + mDNS (5353)...');
    final Map<String, String> udpDiscovered = await _udpBroadcastDiscovery(
      subnet: subnet,
      broadcastIp: broadcastIp,
      localIp: localIp,
    );

    for (final entry in udpDiscovered.entries) {
      final ip = entry.key;
      final protocol = entry.value;
      if (!discovered.containsKey(ip)) {
        print('>>> [UDP] DISPOSITIVO VIA BROADCAST: $ip (Protocolo: $protocol)');
        discovered[ip] = _buildDevice(ip, null, protocol, localIp, mac: null);
      } else {
        print('>>> [UDP+ARP] Confirmado por UDP: $ip');
      }
    }
    print('>>> [FASE 2 - UDP] Nuevos dispositivos por broadcast: ${udpDiscovered.length}');

    // ═══════════════════════════════════════════════════════════════
    // FASE 3: TCP SOCKET PARALELO — 254 IPs simultáneas, 250ms timeout
    //         Complementa los hallazgos ARP/UDP con detección activa.
    // ═══════════════════════════════════════════════════════════════
    final List<int> tcpPorts = [135, 139, 445, 5357, 2869, 80, 443, 5353, 8080];
    print('>>> [FASE 3 - TCP] Escaneando $subnet.1–$subnet.254 en paralelo (timeout 250ms)...');
    print('>>> [FASE 3 - TCP] Puertos: ${tcpPorts.join(', ')}');

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
        discovered[ip] = _buildDevice(ip, null, reason, localIp, mac: null);
      } else {
        // Ya detectado por ARP o UDP — enriquecer con método TCP
        print('>>> [TCP+PREV] Confirmado: $ip ($reason)');
        final existing = discovered[ip]!;
        discovered[ip] = ConnectedDevice(
          id: existing.id,
          name: existing.name,
          ipAddress: existing.ipAddress,
          macAddress: existing.macAddress,
          isOnline: true,
          interfaceType: existing.interfaceType,
          // Si ya tenía MAC real de ARP, conservamos esa info; si no, usamos TCP
          interfaceLabel: existing.macAddress.startsWith('02:00:00:00:00:0')
              ? existing.interfaceLabel
              : '${existing.interfaceLabel} + TCP',
        );
      }
    }

    // Garantizar que el propio teléfono siempre aparezca
    if (!discovered.containsKey(localIp)) {
      discovered[localIp] = ConnectedDevice(
        id: localIp.split('.').last,
        name: 'Este Teléfono (Android)',
        ipAddress: localIp,
        macAddress: '02:00:00:00:00:LOCAL',
        isOnline: true,
        interfaceType: DeviceInterfaceType.wifi50,
        interfaceLabel: 'Este Dispositivo',
      );
    }

    final List<ConnectedDevice> activeDevices = discovered.values.toList();

    stopwatch.stop();
    final double elapsedSeconds = stopwatch.elapsedMilliseconds / 1000.0;
    print('>>> ===================================================');
    print('>>> ESCANEO 4 FASES COMPLETADO EN ${elapsedSeconds.toStringAsFixed(2)} SEGUNDOS!');
    print('>>> Dispositivos únicos detectados: ${activeDevices.length}');
    for (final dev in activeDevices) {
      print('    -> [${dev.ipAddress}] ${dev.name} (${dev.macAddress}) - ${dev.interfaceLabel}');
    }
    print('>>> ===================================================');

    return activeDevices;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FASE 0: ARP KICK SPRAY
  // Envía paquetes UDP mínimos a todos los hosts de la subred para que el
  // kernel de Android emita peticiones ARP en la capa Ethernet/Wi-Fi,
  // registrando las MACs que respondan en /proc/net/arp.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _arpKickSpray(String subnet, String localIp) async {
    try {
      final RawDatagramSocket socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      // Enviar a puertos 80 (UDP no es TCP, pero genera el ARP) y 137 (NetBIOS)
      for (int i = 1; i <= 254; i++) {
        final target = '$subnet.$i';
        if (target == localIp) continue;
        try {
          socket.send(_arpKickPacket, InternetAddress(target), 80);
          socket.send(_arpKickPacket, InternetAddress(target), 137);
        } catch (_) {}
      }
      socket.close();
      print('>>> [ARP KICK] Ráfaga enviada a ${253} IPs de la subred $subnet');
    } catch (e) {
      print('>>> [ARP KICK] Error al enviar ráfaga: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FASE 1: LEER TABLA ARP DEL KERNEL
  // Estrategia multicapa:
  //   1. Intento principal: leer /proc/net/arp directamente
  //   2. Fallback: ejecutar comando `ip neigh` del sistema
  // Nota: En Android 10+ (API 29+) SELinux puede bloquear /proc/net/arp.
  //       El fallback `ip neigh` también puede estar restringido.
  //       Ambos se intentan silenciosamente y se reporta el resultado.
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, String>> _readArpTable(String subnet, String localIp) async {
    final Map<String, String> arpMap = {};

    // ── Intento 1: /proc/net/arp
    try {
      final File arpFile = File('/proc/net/arp');
      if (await arpFile.exists()) {
        final List<String> lines = await arpFile.readAsLines();
        print('>>> [ARP] /proc/net/arp accesible. Líneas: ${lines.length}');
        // Formato: IP address  HW type  Flags  HW address  Mask  Device
        // Ej:      192.168.1.1 0x1       0x2   aa:bb:cc:dd:ee:ff *  wlan0
        for (int i = 1; i < lines.length; i++) {
          final parts = lines[i].trim().split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final String ip = parts[0];
            final String flags = parts[2]; // 0x0 = incompleto, 0x2 = válido
            final String mac = parts[3].toUpperCase();
            // Solo incluir entradas válidas (flags != 0x0) con MAC real
            if (flags != '0x0' &&
                mac != '00:00:00:00:00:00' &&
                ip.startsWith(subnet) &&
                ip != localIp) {
              arpMap[ip] = mac;
            }
          }
        }
        print('>>> [ARP] Entradas válidas en /proc/net/arp: ${arpMap.length}');
      } else {
        print('>>> [ARP] /proc/net/arp no existe o acceso denegado (SELinux)');
      }
    } catch (e) {
      print('>>> [ARP] Error leyendo /proc/net/arp: $e');
    }

    // ── Intento 2: comando `ip neigh` (fallback si /proc/net/arp está bloqueado)
    if (arpMap.isEmpty) {
      try {
        print('>>> [ARP] Intentando fallback: ejecutar `ip neigh`...');
        final ProcessResult result = await Process.run('ip', ['neigh'])
            .timeout(const Duration(seconds: 3));

        if (result.exitCode == 0 && result.stdout != null) {
          final String output = result.stdout as String;
          print('>>> [ARP] Salida de `ip neigh`:\n$output');
          final List<String> lines = output.split('\n');
          for (final line in lines) {
            final parts = line.trim().split(RegExp(r'\s+'));
            // Formato: IP dev IFACE lladdr MAC state STATE
            // Ej: 192.168.1.1 dev wlan0 lladdr aa:bb:cc:dd:ee:ff REACHABLE
            if (parts.length >= 5) {
              final String ip = parts[0];
              final String state = parts.last.toUpperCase();
              // Solo REACHABLE y STALE son entradas con vecino real
              if ((state == 'REACHABLE' || state == 'STALE' || state == 'DELAY') &&
                  ip.startsWith(subnet) &&
                  ip != localIp) {
                final int lladdrIdx = parts.indexOf('lladdr');
                final String mac = (lladdrIdx >= 0 && lladdrIdx + 1 < parts.length)
                    ? parts[lladdrIdx + 1].toUpperCase()
                    : '00:00:00:00:00:00';
                if (mac != '00:00:00:00:00:00') {
                  arpMap[ip] = mac;
                }
              }
            }
          }
          print('>>> [ARP] Entradas válidas en `ip neigh`: ${arpMap.length}');
        } else {
          print('>>> [ARP] `ip neigh` falló (exit: ${result.exitCode}) — restringido por SELinux');
        }
      } catch (e) {
        print('>>> [ARP] Error ejecutando `ip neigh`: $e');
      }
    }

    return arpMap;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FASE 2: UDP BROADCAST — escucha respuestas durante 500ms
  // Envía: SSDP M-SEARCH (1900) → broadcast/multicast
  //        NetBIOS Name Query (137) → unicast a cada IP
  //        mDNS query (5353) → multicast Apple/Android
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, String>> _udpBroadcastDiscovery({
    required String subnet,
    required String broadcastIp,
    required String localIp,
  }) async {
    final Map<String, String> found = {};

    try {
      final RawDatagramSocket socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;

      // SSDP M-SEARCH al broadcast de la subred y multicast UPnP
      try {
        socket.send(_ssdpMSearch, InternetAddress(broadcastIp), 1900);
        socket.send(_ssdpMSearch, InternetAddress('239.255.255.250'), 1900);
      } catch (_) {}

      // NetBIOS Name Query unicast a cada IP (fuerza respuesta de Windows)
      for (int i = 1; i <= 254; i++) {
        final target = '$subnet.$i';
        if (target == localIp) continue;
        try {
          socket.send(_netbiosNameQuery, InternetAddress(target), 137);
        } catch (_) {}
      }

      // mDNS al multicast estándar 224.0.0.251
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

      // Escuchar respuestas durante 500ms
      final Completer<void> completer = Completer();
      final Timer timer = Timer(const Duration(milliseconds: 500), () {
        if (!completer.isCompleted) completer.complete();
      });

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final Datagram? dg = socket.receive();
          if (dg != null) {
            final String senderIp = dg.address.address;
            if (senderIp != localIp &&
                senderIp.startsWith(subnet) &&
                !senderIp.endsWith('.255') &&
                !found.containsKey(senderIp)) {
              String protocol = 'UDP Response (Puerto ${dg.port})';
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
  // FASE 3: TCP PROBE — socket connect a 254 IPs en paralelo
  // Activo si: (a) conexión exitosa, o (b) rechazo explícito del host (TCP RST)
  // Ignora: ICMP Unreachable del router (falso positivo, error 113)
  // ─────────────────────────────────────────────────────────────────────────
  Future<MapEntry<String, String>?> _tcpProbeHost(
    String ip,
    List<int> ports,
    String localIp,
  ) async {
    if (ip == localIp) return MapEntry(ip, 'Este Dispositivo');

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

        final bool isUnreachable = msg.contains('unreachable') ||
            msg.contains('no route') ||
            errStr.contains('113');

        if (!isUnreachable && (msg.contains('refused') || msg.contains('reset'))) {
          return MapEntry(ip, _portLabel(port, 'RST'));
        }
      } catch (_) {}
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  ConnectedDevice _buildDevice(
    String ip,
    String? forcedName,
    String detectionReason,
    String localIp, {
    required String? mac,
  }) {
    final bool isSelf = ip == localIp;
    final String hostHex =
        int.parse(ip.split('.').last).toRadixString(16).padLeft(2, '0').toUpperCase();
    final String resolvedMac = isSelf
        ? '02:00:00:00:00:LOCAL'
        : (mac ?? '02:00:00:00:00:$hostHex');

    return ConnectedDevice(
      id: ip.split('.').last,
      name: forcedName ?? _guessName(ip),
      ipAddress: ip,
      macAddress: resolvedMac,
      isOnline: true,
      interfaceType: isSelf ? DeviceInterfaceType.wifi50 : DeviceInterfaceType.wifi24,
      interfaceLabel: detectionReason,
    );
  }

  String _guessName(String ip) {
    if (ip.endsWith('.1')) return 'Router / Gateway Principal';
    return 'Equipo ($ip)';
  }

  String _portLabel(int port, String status) {
    switch (port) {
      case 135:
        return 'Windows RPC/DCE (P$port $status)';
      case 139:
        return 'NetBIOS/SMB (P$port $status)';
      case 445:
        return 'SMB Archivos (P$port $status)';
      case 5357:
        return 'WSD Windows (P$port $status)';
      case 2869:
        return 'UPnP Eventing (P$port $status)';
      case 5353:
        return 'mDNS Android/iOS (P$port $status)';
      case 80:
        return 'HTTP Web (P$port $status)';
      case 443:
        return 'HTTPS (P$port $status)';
      case 8080:
        return 'HTTP Alt (P$port $status)';
      default:
        return 'Puerto $port $status';
    }
  }
}
