class WifiCredentialsPayload {
  final String contractId;
  final String ssid;
  final String password;
  final String band; // '2.4GHz', '5GHz' o 'dual'

  WifiCredentialsPayload({
    required this.contractId,
    required this.ssid,
    required this.password,
    required this.band,
  });

  Map<String, dynamic> toJson() {
    return {
      'contract_id': contractId,
      'ssid': ssid,
      'password': password,
      'band': band,
    };
  }

  factory WifiCredentialsPayload.fromJson(Map<String, dynamic> json) {
    return WifiCredentialsPayload(
      contractId: json['contract_id'] ?? '',
      ssid: json['ssid'] ?? '',
      password: json['password'] ?? '',
      band: json['band'] ?? '2.4GHz',
    );
  }
}
