import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/connected_device.dart';
import 'device_datasource.dart';
import '../../../../core/error/exceptions.dart';

// Paquete M-SEARCH SSDP/UPnP (RFC 2616)
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

// NetBIOS Name Query (RFC 1002)
const List<int> _netbiosNameQuery = [
  0x82, 0x28, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x20, 0x43, 0x4b, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
  0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
  0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
  0x41, 0x00, 0x00, 0x21, 0x00, 0x01,
];

// Resultado de la sonda TCP por IP
enum _TcpResult { open, refused, timeout, unreachable }

class _ProbeResult {
  final String ip;
  final _TcpResult result;
  final String detail;
  final String? mac; // MAC real de ARP si está disponible

  _ProbeResult(this.ip, this.result, this.detail, {this.mac});
}

class DevicesLocalScannerDataSourceImpl implements DeviceDataSource {
  final NetworkInfo networkInfo;

  DevicesLocalScannerDataSourceImpl({required this.networkInfo});

  @override
  Future<List<ConnectedDevice>> getConnectedDevices() async {
    final Stopwatch sw = Stopwatch()..start();
    print('>>> =======================================================');
    print('>>> ISP Scanner v1.0.11 — ARP Estricto + TCP Sin Falsos Positivos');

    // ── Permisos
    final permStatus = await Permission.location.request();
    if (!permStatus.isGranted) {
      throw PermissionException('Permisos de ubicación denegados.');
    }

    // ── IP local
    final String? localIp = await networkInfo.getWifiIP();
    print('>>> IP local del dispositivo: $localIp');
    if (localIp == null || localIp.isEmpty || localIp == '0.0.0.0') {
      throw PermissionException('No se pudo leer la IP Wi-Fi. Verifica conexión.');
    }

    final parts = localIp.split('.');
    if (parts.length != 4) throw PermissionException('IP inválida: $localIp');
    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
    final broadcast = '$subnet.255';
    print('>>> Subred objetivo: $subnet.1 – $subnet.254');

    // Mapa de resultados final (IP → ConnectedDevice)
    final Map<String, ConnectedDevice> found = {};

    // ═══════════════════════════════════════════════════════
    // FASE 0 — ARP KICK PARALELO (50ms timeout por socket)
    // Envia un intento TCP a cada IP simultáneamente.
    // Objetivo: forzar que el kernel Android resuelva la MAC
    // de cada host a través de ARP antes de continuar.
    // ═══════════════════════════════════════════════════════
    print('>>> [F0] ARP KICK — Enviando 254 sondas UDP paralelas (50ms)...');
    await _arpKickParallel(subnet, localIp);

    // Pausa crítica: dar tiempo al kernel para registrar respuestas ARP
    await Future.delayed(const Duration(milliseconds: 500));

    // ═══════════════════════════════════════════════════════
    // FASE 1 — LECTURA TABLA ARP (/proc/net/arp + ip neigh)
    // Extrae MACs válidas del cache ARP del kernel.
    // Funciona aunque todos los puertos TCP/UDP estén cerrados.
    // ═══════════════════════════════════════════════════════
    print('>>> [F1] ARP READ — Leyendo tabla ARP del kernel...');
    final Map<String, String> arpTable = await _readArpTable(subnet, localIp);
    print('>>> [F1] ARP READ — IPs con MAC válida: ${arpTable.length} → ${arpTable.keys.toList()}');

    for (final e in arpTable.entries) {
      if (e.key == localIp) continue;
      print('>>> [ARP ✓] Dispositivo real: ${e.key} (MAC: ${e.value})');
      found[e.key] = _makeDevice(
        ip: e.key,
        name: _guessByIp(e.key),
        mac: e.value,
        label: 'LAN/Wi-Fi (ARP - MAC: ${e.value})',
        localIp: localIp,
      );
    }

    // ═══════════════════════════════════════════════════════
    // FASE 2 — UDP BROADCAST (SSDP + NetBIOS + mDNS, 500ms)
    // Captura respuestas de servicios de anuncio de red.
    // ═══════════════════════════════════════════════════════
    print('>>> [F2] UDP BROADCAST — SSDP:1900 + NetBIOS:137 + mDNS:5353...');
    final Map<String, String> udp = await _udpBroadcast(subnet, broadcast, localIp);
    for (final e in udp.entries) {
      if (!found.containsKey(e.key)) {
        print('>>> [UDP ✓] Dispositivo broadcast: ${e.key} (${e.value})');
        found[e.key] = _makeDevice(
          ip: e.key,
          name: _guessByIp(e.key),
          mac: arpTable[e.key],
          label: e.value,
          localIp: localIp,
        );
      }
    }

    // ═══════════════════════════════════════════════════════
    // FASE 3 — TCP PARALELO (300ms timeout)
    //
    // Solo se considera vivo un host si:
    //  ① Conexión exitosa (puerto abierto)
    //  ② errno 111 / "refused" / "reset" → TCP RST del host destino
    //
    // Timeout → DESCARTADO (el kernel tarda ~3s en emitir EHOSTUNREACH
    //   para IPs que no existen, más que nuestro timeout → falsos positivos)
    //
    // EHOSTUNREACH (errno 113) → IP vacía, descartada.
    // ═══════════════════════════════════════════════════════
    final List<int> ports = [135, 139, 445, 5357, 2869, 80, 443, 5353, 8080];
    print('>>> [F3] TCP ESTRICTO — 254 IPs × ${ports.length} puertos (300ms timeout)...');

    final List<Future<_ProbeResult>> tasks = [
      for (int i = 1; i <= 254; i++)
        _tcpProbe('$subnet.$i', ports, localIp, arpTable['$subnet.$i']),
    ];
    final List<_ProbeResult> probes = await Future.wait(tasks);

    for (final p in probes) {
      if (p.ip == localIp) continue;

      switch (p.result) {
        case _TcpResult.open:
        case _TcpResult.refused:
          // Host definitivamente vivo → siempre incluir
          if (!found.containsKey(p.ip)) {
            print('>>> [TCP ✓] Host activo: ${p.ip} (${p.detail})');
            found[p.ip] = _makeDevice(
              ip: p.ip,
              name: _guessByIp(p.ip),
              mac: p.mac ?? arpTable[p.ip],
              label: p.detail,
              localIp: localIp,
            );
          } else {
            print('>>> [TCP+] Confirmado por TCP: ${p.ip} (${p.detail})');
          }
          break;

        case _TcpResult.timeout:
          // DESCARTADO — timeout no es evidencia suficiente de host vivo.
          // El kernel Android puede tardar >3s en enviar EHOSTUNREACH para
          // IPs inexistentes, causando 100+ falsos positivos con timeout corto.
          // Los hosts reales son capturados por ARP (FASE 1) o TCP RST/open.
          break;

        case _TcpResult.unreachable:
          // IP vacía — definitivamente muerta, ignorar.
          break;
      }
    }

    // Asegurar que el propio teléfono aparezca siempre
    found[localIp] ??= ConnectedDevice(
      id: parts[3],
      name: 'Este Teléfono (Android)',
      ipAddress: localIp,
      macAddress: '02:00:00:00:00:LOCAL',
      isOnline: true,
      interfaceType: DeviceInterfaceType.wifi50,
      interfaceLabel: 'Este Dispositivo',
    );

    final List<ConnectedDevice> result = found.values.toList();
    sw.stop();

    print('>>> =======================================================');
    print('>>> ESCANEO COMPLETADO EN ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)}s');
    print('>>> Dispositivos encontrados: ${result.length}');
    for (final d in result) {
      print('    → [${d.ipAddress}] ${d.name} | ${d.interfaceLabel}');
    }
    print('>>> =======================================================');

    return result;
  }

  // ─── FASE 0: ARP Kick ───────────────────────────────────────────────────
  // Envía paquetes UDP a las 254 IPs en paralelo con timeout de 50ms.
  // No importa el resultado — el objetivo es que el kernel Android
  // emita peticiones ARP broadcast para cada IP.
  Future<void> _arpKickParallel(String subnet, String localIp) async {
    try {
      final RawDatagramSocket sock = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, 0,
      );
      // Puerto 137 (NetBIOS) y 5353 (mDNS) — más probable que pasen el Wi-Fi
      final List<int> kickPorts = [137, 5353, 80];
      for (int i = 1; i <= 254; i++) {
        final target = '$subnet.$i';
        if (target == localIp) continue;
        for (final p in kickPorts) {
          try {
            sock.send([0x00, 0x00, 0x00, 0x00], InternetAddress(target), p);
          } catch (_) {}
        }
      }
      await Future.delayed(const Duration(milliseconds: 50));
      sock.close();
      print('>>> [F0] ARP Kick enviado a 253 IPs de $subnet');
    } catch (e) {
      print('>>> [F0] ARP Kick error: $e');
    }
  }

  // ─── FASE 1: Leer tabla ARP — VALIDACIÓN ESTRICTA ──────────────────────────
  //
  // Reglas de aceptación (solo entradas REALES, sin falsos positivos):
  //   ✅ flags == '0x2' (entrada completa y válida)
  //   ✅ MAC != '00:00:00:00:00:00' (no placeholder vacío)
  //   ✅ IP en la subred local (no multicast 224.x, no broadcast)
  //   ✅ IP no termina en .255 (no broadcast de subred)
  //   ✅ IP no empieza en 224. / 239. / 255. (no multicast/broadcast)
  //
  // Intentos:
  //   1. /proc/net/arp — directo (puede estar bloqueado por SELinux en Android 10+)
  //   2. `ip neigh`   — fallback via proceso (también puede estar restringido)
  Future<Map<String, String>> _readArpTable(String subnet, String localIp) async {
    final Map<String, String> map = {};

    bool _isValidArpEntry(String ip, String mac, {String? flags}) {
      // Validar flags solo si se proveen (0x2 = COMPLETE, 0x0 = INCOMPLETE)
      if (flags != null && flags != '0x2') return false;
      // MAC real y no vacía
      if (mac == '00:00:00:00:00:00' || mac.isEmpty) return false;
      // No multicast ni broadcast
      if (ip.endsWith('.255')) return false;
      if (ip.startsWith('224.') || ip.startsWith('239.') || ip.startsWith('255.')) return false;
      // Debe estar en la subred local
      if (!ip.startsWith(subnet)) return false;
      // No es el propio dispositivo
      if (ip == localIp) return false;
      return true;
    }

    // ── Intento 1: /proc/net/arp
    try {
      final f = File('/proc/net/arp');
      if (await f.exists()) {
        final lines = await f.readAsLines();
        print('>>> [F1] /proc/net/arp leído — ${lines.length} líneas brutas');
        // Formato: IP address  HW type  Flags  HW address  Mask  Device
        // Ejemplo: 192.168.1.1  0x1  0x2  aa:bb:cc:dd:ee:ff  *  wlan0
        int valid = 0;
        for (int i = 1; i < lines.length; i++) {
          final cols = lines[i].trim().split(RegExp(r'\s+'));
          if (cols.length >= 4) {
            final ip    = cols[0];
            final flags = cols[2]; // '0x2' = completo, '0x0' = incompleto
            final mac   = cols[3].toUpperCase();
            if (_isValidArpEntry(ip, mac, flags: flags)) {
              map[ip] = mac;
              valid++;
              print('>>> [ARP] Entrada válida: $ip → $mac (flags=$flags)');
            } else {
              print('>>> [ARP] Entrada descartada: $ip mac=$mac flags=$flags');
            }
          }
        }
        print('>>> [F1] /proc/net/arp — entradas válidas: $valid / ${lines.length - 1}');
        return map;
      } else {
        print('>>> [F1] /proc/net/arp: no accesible (SELinux en Android 10+)');
      }
    } catch (e) {
      print('>>> [F1] /proc/net/arp error: $e');
    }

    // ── Intento 2: ip neigh (fallback)
    try {
      print('>>> [F1] Fallback: ejecutando `ip neigh`...');
      final res = await Process.run('ip', ['neigh'])
          .timeout(const Duration(seconds: 3));
      if (res.exitCode == 0 && res.stdout != null) {
        final out = res.stdout as String;
        // Formato: IP dev IFACE lladdr MAC state STATE
        // Solo aceptar REACHABLE (equivale a flags=0x2)
        for (final line in out.split('\n')) {
          final cols = line.trim().split(RegExp(r'\s+'));
          if (cols.length >= 5) {
            final ip    = cols[0];
            final state = cols.last.toUpperCase();
            // Solo REACHABLE = entrada activa confirmada (STALE/DELAY son entradas antiguas no confirmadas)
            if (state != 'REACHABLE') continue;
            final li  = cols.indexOf('lladdr');
            if (li < 0 || li + 1 >= cols.length) continue;
            final mac = cols[li + 1].toUpperCase();
            if (_isValidArpEntry(ip, mac)) {
              map[ip] = mac;
              print('>>> [ARP] ip neigh REACHABLE: $ip → $mac');
            }
          }
        }
        print('>>> [F1] `ip neigh` — entradas REACHABLE válidas: ${map.length}');
      } else {
        print('>>> [F1] `ip neigh` bloqueado (exit=${res.exitCode}) — SELinux');
      }
    } catch (e) {
      print('>>> [F1] `ip neigh` error: $e');
    }

    return map;
  }

  // ─── FASE 2: UDP Broadcast ──────────────────────────────────────────────
  Future<Map<String, String>> _udpBroadcast(
    String subnet, String broadcast, String localIp,
  ) async {
    final Map<String, String> resp = {};
    try {
      final sock = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, 0, reuseAddress: true,
      );
      sock.broadcastEnabled = true;

      // SSDP broadcast + multicast
      try { sock.send(_ssdpMSearch, InternetAddress(broadcast), 1900); } catch (_) {}
      try { sock.send(_ssdpMSearch, InternetAddress('239.255.255.250'), 1900); } catch (_) {}

      // NetBIOS unicast a cada IP
      for (int i = 1; i <= 254; i++) {
        final t = '$subnet.$i';
        if (t == localIp) continue;
        try { sock.send(_netbiosNameQuery, InternetAddress(t), 137); } catch (_) {}
      }

      // mDNS multicast
      const List<int> mdns = [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x05, 0x5f, 0x68, 0x74,
        0x74, 0x70, 0x04, 0x5f, 0x74, 0x63, 0x70, 0x05,
        0x6c, 0x6f, 0x63, 0x61, 0x6c, 0x00, 0x00, 0x0c, 0x00, 0x01,
      ];
      try { sock.send(mdns, InternetAddress('224.0.0.251'), 5353); } catch (_) {}

      final comp = Completer<void>();
      Timer(const Duration(milliseconds: 500), () {
        if (!comp.isCompleted) comp.complete();
      });

      sock.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = sock.receive();
          if (dg != null) {
            final ip = dg.address.address;
            if (ip != localIp &&
                ip.startsWith(subnet) &&
                !ip.endsWith('.255') &&
                !resp.containsKey(ip)) {
              String proto = 'UDP:${dg.port}';
              if (dg.port == 1900 || dg.port == 1901) proto = 'SSDP/UPnP';
              else if (dg.port == 137 || dg.port == 138) proto = 'NetBIOS';
              else if (dg.port == 5353) proto = 'mDNS';
              resp[ip] = proto;
            }
          }
        }
      });

      await comp.future;
      sock.close();
    } catch (_) {}
    return resp;
  }

  // ─── FASE 3: TCP Probe diferenciado (600ms timeout) ─────────────────────
  Future<_ProbeResult> _tcpProbe(
    String ip, List<int> ports, String localIp, String? knownMac,
  ) async {
    if (ip == localIp) {
      return _ProbeResult(ip, _TcpResult.open, 'Este Dispositivo', mac: knownMac);
    }

    for (final port in ports) {
      try {
        final Socket sock = await Socket.connect(
          ip, port,
          timeout: const Duration(milliseconds: 300),
        );
        sock.destroy();
        return _ProbeResult(ip, _TcpResult.open, _pl(port, 'Abierto'), mac: knownMac);
      } on SocketException catch (e) {
        final msg = e.message.toLowerCase();
        final err = e.toString().toLowerCase();

        final bool isUnreachable =
            msg.contains('unreachable') ||
            msg.contains('no route') ||
            err.contains('113') ||
            err.contains('ehostunreach') ||
            err.contains('enetunreach');

        if (isUnreachable) {
          // IP vacía / muerta — no seguir probando puertos
          return _ProbeResult(ip, _TcpResult.unreachable, 'EHOSTUNREACH', mac: knownMac);
        }

        if (msg.contains('refused') || msg.contains('reset')) {
          // TCP RST del host — definitivamente vivo
          return _ProbeResult(ip, _TcpResult.refused, _pl(port, 'RST'), mac: knownMac);
        }
        // Otro SocketException (ej. timeout del socket) → sigue probando
      } on TimeoutException {
        // Timeout puro — posiblemente vivo (Windows Firewall silencioso)
        // Solo reportar en el ÚLTIMO puerto para no saturar logs
        if (port == ports.last) {
          return _ProbeResult(ip, _TcpResult.timeout, 'Timeout (${ports.join(',')}) - Posible Firewall', mac: knownMac);
        }
      } catch (_) {}
    }

    // Todos los puertos dieron timeout → probablemente firewall activo
    return _ProbeResult(
      ip, _TcpResult.timeout,
      'Timeout todos los puertos — Posible Firewall Windows',
      mac: knownMac,
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  ConnectedDevice _makeDevice({
    required String ip,
    required String name,
    required String? mac,
    required String label,
    required String localIp,
  }) {
    final bool isSelf = ip == localIp;
    final hex = int.parse(ip.split('.').last)
        .toRadixString(16).padLeft(2, '0').toUpperCase();
    final resolvedMac = isSelf
        ? '02:00:00:00:00:LOCAL'
        : (mac != null && mac != '00:00:00:00:00:00' ? mac : '02:00:00:00:00:$hex');

    return ConnectedDevice(
      id: ip.split('.').last,
      name: name,
      ipAddress: ip,
      macAddress: resolvedMac,
      isOnline: true,
      interfaceType: isSelf ? DeviceInterfaceType.wifi50 : DeviceInterfaceType.wifi24,
      interfaceLabel: label,
    );
  }

  String _guessByIp(String ip) {
    if (ip.endsWith('.1')) return 'Router / Gateway Principal';
    return 'Equipo ($ip)';
  }

  String _pl(int port, String status) {
    const Map<int, String> labels = {
      135: 'Windows RPC',
      139: 'NetBIOS/SMB',
      445: 'SMB Archivos',
      5357: 'WSD Windows',
      2869: 'UPnP Eventing',
      5353: 'mDNS',
      80: 'HTTP',
      443: 'HTTPS',
      8080: 'HTTP Alt',
    };
    return '${labels[port] ?? 'P$port'} ($status)';
  }
}
