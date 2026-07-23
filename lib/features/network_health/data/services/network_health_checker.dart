import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:network_info_plus/network_info_plus.dart';

enum WifiStatus { optimal, unstable, disconnected }
enum WanStatus { excellent, degraded, offline }
enum SectorStatus { operational, incidentReported, unknown }

class NetworkHealthResult {
  final WifiStatus wifiStatus;
  final int wifiLatencyMs;
  final WanStatus wanStatus;
  final int wanLatencyMs;
  final SectorStatus sectorStatus;
  final String sectorMessage;
  final DateTime timestamp;

  NetworkHealthResult({
    required this.wifiStatus,
    required this.wifiLatencyMs,
    required this.wanStatus,
    required this.wanLatencyMs,
    required this.sectorStatus,
    required this.sectorMessage,
    required this.timestamp,
  });

  bool get isOverallGreen =>
      wifiStatus == WifiStatus.optimal &&
      wanStatus == WanStatus.excellent &&
      sectorStatus == SectorStatus.operational;

  bool get isOverallRed =>
      wanStatus == WanStatus.offline ||
      sectorStatus == SectorStatus.incidentReported ||
      wifiStatus == WifiStatus.disconnected;

  bool get isOverallYellow => !isOverallGreen && !isOverallRed;
}

class NetworkHealthChecker {
  final NetworkInfo networkInfo;
  final Dio dio;

  NetworkHealthChecker({
    required this.networkInfo,
    required this.dio,
  });

  Future<NetworkHealthResult> runFullDiagnostic() async {
    final DateTime now = DateTime.now();

    // 1. Obtener IP local del celular y Gateway
    final String? localIp = await networkInfo.getWifiIP();
    if (localIp == null || localIp.isEmpty || localIp == '0.0.0.0') {
      return NetworkHealthResult(
        wifiStatus: WifiStatus.disconnected,
        wifiLatencyMs: 0,
        wanStatus: WanStatus.offline,
        wanLatencyMs: 0,
        sectorStatus: SectorStatus.unknown,
        sectorMessage: 'No estás conectado a ninguna red Wi-Fi.',
        timestamp: now,
      );
    }

    final ipParts = localIp.split('.');
    final String gatewayIp = '${ipParts[0]}.${ipParts[1]}.${ipParts[2]}.1';

    // ── TEST A: WI-FI LOCAL (Gateway 192.168.1.1, timeout 1.5s)
    final wifiLatency = await _measureTcpLatency(gatewayIp, 80, const Duration(milliseconds: 1500));
    WifiStatus wifiStatus;
    if (wifiLatency < 0) {
      // Intentar puerto 443 si el 80 no respondió
      final altWifi = await _measureTcpLatency(gatewayIp, 443, const Duration(milliseconds: 1500));
      wifiStatus = altWifi < 0
          ? WifiStatus.unstable
          : (altWifi <= 20 ? WifiStatus.optimal : WifiStatus.unstable);
    } else if (wifiLatency <= 20) {
      wifiStatus = WifiStatus.optimal;
    } else {
      wifiStatus = WifiStatus.unstable;
    }

    // ── TEST B: SALIDA WAN (DNS público 1.1.1.1 o 8.8.8.8, timeout 2s)
    int wanLatency = await _measureTcpLatency('1.1.1.1', 53, const Duration(seconds: 2));
    if (wanLatency < 0) {
      wanLatency = await _measureTcpLatency('8.8.8.8', 53, const Duration(seconds: 2));
    }

    WanStatus wanStatus;
    if (wanLatency < 0) {
      wanStatus = WanStatus.offline;
    } else if (wanLatency <= 80) {
      wanStatus = WanStatus.excellent;
    } else {
      wanStatus = WanStatus.degraded;
    }

    // ── TEST C: CONSULTA DE SECTOR (GET /api/v1/service-status/sector)
    SectorStatus sectorStatus = SectorStatus.operational;
    String sectorMessage = 'Sector operativo sin novedades reportadas.';

    try {
      final response = await dio
          .get('/api/v1/service-status/sector')
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final bool hasIncident = data['has_incident'] ?? false;
        if (hasIncident) {
          sectorStatus = SectorStatus.incidentReported;
          sectorMessage = data['message'] ?? 'Incidencia masiva en mantenimiento técnico en tu zona.';
        }
      }
    } catch (_) {
      // Si el backend no responde, se asume sin incidencias de sector locales
    }

    return NetworkHealthResult(
      wifiStatus: wifiStatus,
      wifiLatencyMs: wifiLatency < 0 ? 999 : wifiLatency,
      wanStatus: wanStatus,
      wanLatencyMs: wanLatency < 0 ? 999 : wanLatency,
      sectorStatus: sectorStatus,
      sectorMessage: sectorMessage,
      timestamp: now,
    );
  }

  Future<int> _measureTcpLatency(String host, int port, Duration timeout) async {
    final Stopwatch sw = Stopwatch()..start();
    try {
      final Socket socket = await Socket.connect(host, port, timeout: timeout);
      sw.stop();
      socket.destroy();
      return sw.elapsedMilliseconds;
    } catch (_) {
      sw.stop();
      return -1;
    }
  }
}
