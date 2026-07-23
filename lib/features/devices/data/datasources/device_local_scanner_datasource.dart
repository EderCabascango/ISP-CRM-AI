import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/connected_device.dart';
import 'device_datasource.dart';
import '../../../../core/error/exceptions.dart';

// WS-Discovery (WSD - RFC SOAP) — Probe XML enviado por Windows 10/11 en puerto UDP 3702
const String _wsdProbeXml = '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:wsd="http://schemas.xmlsoap.org/ws/2005/04/discovery">
  <soap:Header>
    <wsa:To>urn:schemas-xmlsoap-org:ws:2005:04:discovery</wsa:To>
    <wsa:Action>http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</wsa:Action>
    <wsa:MessageID>urn:uuid:a1b2c3d4-e5f6-7890-abcd-ef1234567890</wsa:MessageID>
  </soap:Header>
  <soap:Body>
    <wsd:Probe/>
  </soap:Body>
</soap:Envelope>''';

// SSDP M-SEARCH (RFC 2616) — UPnP discovery en puerto UDP 1900
const List<int> _ssdpMSearch = [
  0x4d, 0x2d, 0x53, 0x45, 0x41, 0x52, 0x43, 0x48, 0x20, 0x2a, 0x20,
  0x48, 0x54, 0x54, 0x50, 0x2f, 0x31, 0x2e, 0x31, 0x0d, 0x0a,
  0x48, 0x4f, 0x53, 0x54, 0x3a, 0x20, 0x32, 0x33, 0x39, 0x2e, 0x32,
  0x35, 0x35, 0x2e, 0x32, 0x35, 0x35, 0x2e, 0x32, 0x35, 0x30, 0x3a,
  0x31, 0x39, 0x30, 0x30, 0x0d, 0x0a, 0x4d, 0x41, 0x4e, 0x3a, 0x20,
  0x22, 0x73, 0x73, 0x64, 0x70, 0x3a, 0x64, 0x69, 0x73, 0x63, 0x6f,
  0x76, 0x65, 0x72, 0x22, 0x0d, 0x0a, 0x4d, 0x58, 0x3a, 0x20, 0x33,
  0x0d, 0x0a, 0x53, 0x54, 0x3a, 0x20, 0x73, 0x73, 0x64, 0x70, 0x3a,
  0x61, 0x6c, 0x6c, 0x0d, 0x0a, 0x0d, 0x0a,
];

// NetBIOS Name Query (RFC 1002) — Puerto UDP 137
const List<int> _netbiosNameQuery = [
  0x82, 0x28, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x20, 0x43, 0x4b, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
  0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
  0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
  0x41, 0x00, 0x00, 0x21, 0x00, 0x01,
];

class DevicesLocalScannerDataSourceImpl implements DeviceDataSource {
  final NetworkInfo networkInfo;

  DevicesLocalScannerDataSourceImpl({required this.networkInfo});

  @override
  Future<List<ConnectedDevice>> getConnectedDevices() async {
    final Stopwatch sw = Stopwatch()..start();
    print('>>> =======================================================');
    print('>>> ISP Scanner v1.0.12 — Motor Multiprotocolo (WSD + UDP Broadcast + TCP)');

    // 1. Permisos de ubicación (requeridos para leer la IP local del Wi-Fi)
    final permStatus = await Permission.location.request();
    if (!permStatus.isGranted) {
      throw PermissionException('Permisos de ubicación denegados.');
    }

    // 2. Obtención de la IP local
    final String? localIp = await networkInfo.getWifiIP();
    print('>>> IP local del dispositivo: $localIp');
    if (localIp == null || localIp.isEmpty || localIp == '0.0.0.0') {
      throw PermissionException('No se pudo leer la IP Wi-Fi. Verifica conexión.');
    }

    final parts = localIp.split('.');
    if (parts.length != 4) throw PermissionException('IP inválida: $localIp');
    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
    final broadcastIp = '$subnet.255';
    print('>>> Subred objetivo: $subnet.1 – $subnet.254 | Broadcast: $broadcastIp');

    // Registro consolidado de dispositivos (IP -> ConnectedDevice)
    final Map<String, ConnectedDevice> discovered = {};

    // ═════════════════════════════════════════════════════════════════════════
    // CAPA 1: DISCOVERY UDP MULTIPROTOCOLO (WSD 3702 + SSDP 1900 + mDNS 5353 + NetBIOS 137)
    // ═════════════════════════════════════════════════════════════════════════
    print('>>> [CAPA 1 - UDP] Lanzando sondas multiprotocolo WSD/SSDP/mDNS/NetBIOS...');
    final Map<String, String> udpResults = await _udpMultiprotocolDiscovery(
      subnet: subnet,
      broadcastIp: broadcastIp,
      localIp: localIp,
    );

    for (final entry in udpResults.entries) {
      final ip = entry.key;
      final protocol = entry.value;
      print('>>> [UDP ✓] DISPOSITIVO ENCONTRADO: $ip | Método: $protocol');
      discovered[ip] = _buildDevice(
        ip: ip,
        detectionMethod: protocol,
        localIp: localIp,
      );
    }
    print('>>> [CAPA 1 - UDP] Total detectados por UDP: ${udpResults.length}');

    // ═════════════════════════════════════════════════════════════════════════
    // CAPA 2: LECTURA ARP KERNEL (Bypassea reglas de Firewall si el ARP se resolvió)
    // ═════════════════════════════════════════════════════════════════════════
    print('>>> [CAPA 2 - ARP] Consultando tabla de vecinos ARP del SO...');
    final Map<String, String> arpEntries = await _readArpTable(subnet, localIp);
    for (final entry in arpEntries.entries) {
      final ip = entry.key;
      final mac = entry.value;
      if (!discovered.containsKey(ip)) {
        print('>>> [ARP ✓] DISPOSITIVO ENCONTRADO: $ip | MAC: $mac');
        discovered[ip] = _buildDevice(
          ip: ip,
          mac: mac,
          detectionMethod: 'Tabla ARP Kernel (MAC: $mac)',
          localIp: localIp,
        );
      }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // CAPA 3: BARRIDO PARALELO DE PUERTOS TCP (135, 445, 5357, 3702, 80, 443, 8080, 8000)
    // ═════════════════════════════════════════════════════════════════════════
    final List<int> tcpPorts = [135, 445, 5357, 3702, 80, 443, 8080, 8000];
    print('>>> [CAPA 3 - TCP] Escaneando 254 IPs en paralelo (timeout 250ms)...');
    print('>>> Puertos TCP analizados: ${tcpPorts.join(', ')}');

    final List<Future<MapEntry<String, String>?>> tcpTasks = [
      for (int i = 1; i <= 254; i++)
        _probeTcpHost('$subnet.$i', tcpPorts, localIp)
    ];

    final List<MapEntry<String, String>?> tcpResults = await Future.wait(tcpTasks);

    for (final entry in tcpResults) {
      if (entry == null) continue;
      final ip = entry.key;
      final method = entry.value;

      if (!discovered.containsKey(ip)) {
        print('>>> [TCP ✓] DISPOSITIVO ENCONTRADO: $ip | Método: $method');
        discovered[ip] = _buildDevice(
          ip: ip,
          detectionMethod: method,
          localIp: localIp,
        );
      } else {
        print('>>> [TCP+UDP] Dispositivo $ip re-confirmado vía TCP ($method)');
      }
    }

    // Garantizar inclusión del dispositivo propio
    discovered[localIp] ??= ConnectedDevice(
      id: parts[3],
      name: 'Este Teléfono (Android)',
      ipAddress: localIp,
      macAddress: '02:00:00:00:00:LOCAL',
      isOnline: true,
      interfaceType: DeviceInterfaceType.wifi50,
      interfaceLabel: 'Este Dispositivo',
    );

    final List<ConnectedDevice> finalList = discovered.values.toList();
    sw.stop();

    print('>>> =======================================================');
    print('>>> ESCANEO MULTIPROTOCOLO COMPLETADO EN ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)}s');
    print('>>> Total de dispositivos consolidados: ${finalList.length}');
    for (final dev in finalList) {
      print('    -> [${dev.ipAddress}] ${dev.name} | ${dev.interfaceLabel}');
    }
    print('>>> =======================================================');

    return finalList;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CAPA 1: DESCOBRIMIENTO UDP MULTIPROTOCOLO (Escucha activa por 1.8 segundos)
  // Configura RawDatagramSocket con reuseAddress=true y broadcastEnabled=true
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, String>> _udpMultiprotocolDiscovery({
    required String subnet,
    required String broadcastIp,
    required String localIp,
  }) async {
    final Map<String, String> discoveredUdp = {};

    try {
      final RawDatagramSocket socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;

      // 1. Sonda WS-Discovery (WSD - UDP 3702) -> Multicast Windows 10/11
      try {
        final List<int> wsdBytes = _wsdProbeXml.codeUnits;
        socket.send(wsdBytes, InternetAddress('239.255.255.250'), 3702);
        socket.send(wsdBytes, InternetAddress(broadcastIp), 3702);
      } catch (_) {}

      // 2. Sonda SSDP / UPnP M-SEARCH (UDP 1900)
      try {
        socket.send(_ssdpMSearch, InternetAddress('239.255.255.250'), 1900);
        socket.send(_ssdpMSearch, InternetAddress(broadcastIp), 1900);
      } catch (_) {}

      // 3. Consulta mDNS (UDP 5353) -> Multicast Apple / Smart TV / Android
      try {
        const List<int> mdnsQuery = [
          0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x05, 0x5f, 0x68, 0x74,
          0x74, 0x70, 0x04, 0x5f, 0x74, 0x63, 0x70, 0x05,
          0x6c, 0x6f, 0x63, 0x61, 0x00, 0x00, 0x0c, 0x00, 0x01,
        ];
        socket.send(mdnsQuery, InternetAddress('224.0.0.251'), 5353);
      } catch (_) {}

      // 4. Sondas NetBIOS Unicast a cada IP de la subred (UDP 137)
      for (int i = 1; i <= 254; i++) {
        final target = '$subnet.$i';
        if (target == localIp) continue;
        try {
          socket.send(_netbiosNameQuery, InternetAddress(target), 137);
        } catch (_) {}
      }

      // Escuchar respuestas acumuladas durante 1.8 segundos
      final Completer<void> completer = Completer();
      final Timer timer = Timer(const Duration(milliseconds: 1800), () {
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
                !discoveredUdp.containsKey(senderIp)) {
              
              String protocol = 'UDP Response (Puerto ${dg.port})';
              if (dg.port == 3702) {
                protocol = 'Detectado por WS-Discovery LAN (Puerto 3702)';
              } else if (dg.port == 1900 || dg.port == 1901) {
                protocol = 'Detectado por SSDP / UPnP (Puerto 1900)';
              } else if (dg.port == 5353) {
                protocol = 'Detectado por mDNS Multicast (Puerto 5353)';
              } else if (dg.port == 137 || dg.port == 138) {
                protocol = 'Detectado por NetBIOS Windows (Puerto 137)';
              }

              discoveredUdp[senderIp] = protocol;
            }
          }
        }
      });

      await completer.future;
      timer.cancel();
      socket.close();
    } catch (_) {}

    return discoveredUdp;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CAPA 3: BARRIDO PARALELO TCP (Conexión exitosa o RST / Connection Refused)
  // Timeout estricto de 250ms por socket
  // ─────────────────────────────────────────────────────────────────────────
  Future<MapEntry<String, String>?> _probeTcpHost(
    String ip,
    List<int> ports,
    String localIp,
  ) async {
    if (ip == localIp) return null;

    for (final port in ports) {
      try {
        final Socket socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(milliseconds: 250),
        );
        socket.destroy();
        return MapEntry(ip, 'Detectado por TCP $port (Puerto Abierto)');
      } on SocketException catch (e) {
        final msg = e.message.toLowerCase();
        final err = e.toString().toLowerCase();

        // Evitar falsos positivos de ICMP Unreachable emitidos por el Router
        final bool isUnreachable = msg.contains('unreachable') ||
            msg.contains('no route') ||
            err.contains('113') ||
            err.contains('ehostunreach');

        // Si la conexión fue rechazada activamente por la máquina de destino (TCP RST)
        if (!isUnreachable && (msg.contains('refused') || msg.contains('reset'))) {
          return MapEntry(ip, 'Detectado por TCP $port (Rechazo Activo RST)');
        }
      } catch (_) {}
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CAPA 2: Lectura estricta de la tabla ARP Kernel (/proc/net/arp o ip neigh)
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, String>> _readArpTable(String subnet, String localIp) async {
    final Map<String, String> map = {};

    bool _isValid(String ip, String mac, {String? flags}) {
      if (flags != null && flags != '0x2') return false;
      if (mac == '00:00:00:00:00:00' || mac.isEmpty) return false;
      if (ip.endsWith('.255')) return false;
      if (ip.startsWith('224.') || ip.startsWith('239.') || ip.startsWith('255.')) return false;
      if (!ip.startsWith(subnet) || ip == localIp) return false;
      return true;
    }

    try {
      final f = File('/proc/net/arp');
      if (await f.exists()) {
        final lines = await f.readAsLines();
        for (int i = 1; i < lines.length; i++) {
          final cols = lines[i].trim().split(RegExp(r'\s+'));
          if (cols.length >= 4) {
            final ip = cols[0];
            final flags = cols[2];
            final mac = cols[3].toUpperCase();
            if (_isValid(ip, mac, flags: flags)) {
              map[ip] = mac;
            }
          }
        }
        if (map.isNotEmpty) return map;
      }
    } catch (_) {}

    try {
      final res = await Process.run('ip', ['neigh']).timeout(const Duration(seconds: 2));
      if (res.exitCode == 0 && res.stdout != null) {
        for (final line in (res.stdout as String).split('\n')) {
          final cols = line.trim().split(RegExp(r'\s+'));
          if (cols.length >= 5) {
            final ip = cols[0];
            final state = cols.last.toUpperCase();
            if (state == 'REACHABLE') {
              final li = cols.indexOf('lladdr');
              if (li >= 0 && li + 1 < cols.length) {
                final mac = cols[li + 1].toUpperCase();
                if (_isValid(ip, mac)) map[ip] = mac;
              }
            }
          }
        }
      }
    } catch (_) {}

    return map;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helper de construcción de entidad
  // ─────────────────────────────────────────────────────────────────────────
  ConnectedDevice _buildDevice({
    required String ip,
    required String detectionMethod,
    required String localIp,
    String? mac,
  }) {
    final bool isSelf = ip == localIp;
    final String hostHex = int.parse(ip.split('.').last).toRadixString(16).padLeft(2, '0').toUpperCase();
    final String resolvedMac = isSelf
        ? '02:00:00:00:00:LOCAL'
        : (mac != null && mac != '00:00:00:00:00:00' ? mac : '02:00:00:00:00:$hostHex');

    String name = 'Dispositivo de Red ($ip)';
    if (ip.endsWith('.1')) {
      name = 'Router / Gateway Principal';
    }

    return ConnectedDevice(
      id: ip.split('.').last,
      name: name,
      ipAddress: ip,
      macAddress: resolvedMac,
      isOnline: true,
      interfaceType: isSelf ? DeviceInterfaceType.wifi50 : DeviceInterfaceType.wifi24,
      interfaceLabel: detectionMethod,
    );
  }
}
