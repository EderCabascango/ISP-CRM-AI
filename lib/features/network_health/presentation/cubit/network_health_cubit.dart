import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/network_health_checker.dart';
import 'network_health_state.dart';

class NetworkHealthCubit extends Cubit<NetworkHealthState> {
  final NetworkHealthChecker checker;

  NetworkHealthCubit({required this.checker}) : super(const NetworkHealthInitial());

  Future<void> runDiagnostic() async {
    emit(const NetworkHealthLoading());

    try {
      final result = await checker.runFullDiagnostic();

      if (result.wifiStatus == WifiStatus.disconnected) {
        emit(const NetworkHealthNoWifi(
          'Por favor conéctate a la red Wi-Fi de tu hogar para diagnosticar la salud de tu conexión.',
        ));
      } else {
        emit(NetworkHealthSuccess(result));
      }
    } catch (e) {
      emit(NetworkHealthError('No se pudo ejecutar el diagnóstico: ${e.toString()}'));
    }
  }
}
