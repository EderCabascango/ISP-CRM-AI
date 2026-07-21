import 'package:equatable/equatable.dart';

class WifiNetwork extends Equatable {
  final String ssid24;
  final String password24;
  final bool isEnabled24;
  
  final String ssid50;
  final String password50;
  final bool isEnabled50;

  const WifiNetwork({
    required this.ssid24,
    required this.password24,
    required this.isEnabled24,
    required this.ssid50,
    required this.password50,
    required this.isEnabled50,
  });

  WifiNetwork copyWith({
    String? ssid24,
    String? password24,
    bool? isEnabled24,
    String? ssid50,
    String? password50,
    bool? isEnabled50,
  }) {
    return WifiNetwork(
      ssid24: ssid24 ?? this.ssid24,
      password24: password24 ?? this.password24,
      isEnabled24: isEnabled24 ?? this.isEnabled24,
      ssid50: ssid50 ?? this.ssid50,
      password50: password50 ?? this.password50,
      isEnabled50: isEnabled50 ?? this.isEnabled50,
    );
  }

  @override
  List<Object?> get props => [
        ssid24,
        password24,
        isEnabled24,
        ssid50,
        password50,
        isEnabled50,
      ];
}
