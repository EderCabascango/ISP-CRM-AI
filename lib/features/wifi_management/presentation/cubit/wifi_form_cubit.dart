import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/wifi_credentials_payload.dart';
import '../../domain/repositories/wifi_management_repository.dart';
import 'wifi_form_state.dart';

class WifiFormCubit extends Cubit<WifiFormState> {
  final WifiManagementRepository repository;

  WifiFormCubit({required this.repository}) : super(const WifiFormInitial());

  Future<void> updateCredentials({
    required String contractId,
    required String ssid,
    required String password,
    required String band,
  }) async {
    emit(const WifiFormLoading());

    final payload = WifiCredentialsPayload(
      contractId: contractId,
      ssid: ssid,
      password: password,
      band: band,
    );

    final result = await repository.updateWifiCredentials(payload);

    result.fold(
      (failure) => emit(WifiFormError(failure.message)),
      (_) => emit(const WifiFormSuccess(
        '¡Credenciales actualizadas exitosamente! Tu router aplicará los cambios en breve.',
      )),
    );
  }
}
