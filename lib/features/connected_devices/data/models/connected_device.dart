enum ConnectionType { wifi2G, wifi5G, ethernet }

class ConnectedDevice {
  final String ipAddress;
  final String macAddress;
  final String hostname;
  final ConnectionType connectionType;
  final int? signalStrength; // dBm, null para Ethernet
  final bool isBlocked;

  ConnectedDevice({
    required this.ipAddress,
    required this.macAddress,
    required this.hostname,
    required this.connectionType,
    this.signalStrength,
    required this.isBlocked,
  });

  factory ConnectedDevice.fromJson(Map<String, dynamic> json) {
    ConnectionType connType = ConnectionType.wifi2G;
    final typeStr = (json['connection_type'] ?? '').toString().toLowerCase();
    if (typeStr.contains('5g') || typeStr.contains('5ghz')) {
      connType = ConnectionType.wifi5G;
    } else if (typeStr.contains('ethernet') || typeStr.contains('cable') || typeStr.contains('lan')) {
      connType = ConnectionType.ethernet;
    }

    return ConnectedDevice(
      ipAddress: json['ip_address'] ?? '',
      macAddress: json['mac_address'] ?? '',
      hostname: json['hostname'] ?? 'Dispositivo',
      connectionType: connType,
      signalStrength: json['signal_strength'],
      isBlocked: json['is_blocked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ip_address': ipAddress,
      'mac_address': macAddress,
      'hostname': hostname,
      'connection_type': connectionType.name,
      'signal_strength': signalStrength,
      'is_blocked': isBlocked,
    };
  }
}
