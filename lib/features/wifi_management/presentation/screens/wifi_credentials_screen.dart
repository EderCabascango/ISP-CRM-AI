import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/repositories/wifi_management_repository_impl.dart';
import '../cubit/wifi_form_cubit.dart';
import '../cubit/wifi_form_state.dart';

class WifiCredentialsScreen extends StatefulWidget {
  final String contractId;

  const WifiCredentialsScreen({
    super.key,
    this.contractId = 'CTR-88392',
  });

  @override
  State<WifiCredentialsScreen> createState() => _WifiCredentialsScreenState();
}

class _WifiCredentialsScreenState extends State<WifiCredentialsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  String _selectedBand = 'dual'; // '2.4GHz', '5GHz' o 'dual'

  // Validaciones en tiempo real de contraseña
  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasLetter => RegExp(r'[a-zA-Z]').hasMatch(_passwordController.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_passwordController.text);
  bool get _isPasswordValid => _hasMinLength && _hasLetter && _hasNumber;

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WifiFormCubit(
        repository: WifiManagementRepositoryImpl(
          dio: Dio(BaseOptions(baseUrl: 'https://api.isp-backend.com/v1')),
          secureStorage: const FlutterSecureStorage(),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Actualizar Wi-Fi'),
          centerTitle: true,
        ),
        body: BlocConsumer<WifiFormCubit, WifiFormState>(
          listener: (context, state) {
            if (state is WifiFormError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage),
                  backgroundColor: Colors.red.shade700,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else if (state is WifiFormSuccess) {
              _showSuccessDialog(context, state.message);
            }
          },
          builder: (context, state) {
            final isLoading = state is WifiFormLoading;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner informativo
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_protected_setup, color: Colors.blue.shade700, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Los cambios se enviarán directamente a tu Router/ONT. Al guardar, deberás reconectar tus dispositivos.',
                              style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Campo SSID (Nombre de Red)
                    Text(
                      'Nombre de la Red Wi-Fi (SSID)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _ssidController,
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        hintText: 'Ej. MiHogar_5G',
                        prefixIcon: const Icon(Icons.wifi),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 3) {
                          return 'El nombre de la red debe tener al menos 3 caracteres.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Campo Contraseña
                    Text(
                      'Nueva Contraseña Wi-Fi',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !isLoading,
                      obscureText: !_isPasswordVisible,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Mínimo 8 caracteres',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (!_isPasswordValid) {
                          return 'La contraseña debe cumplir con todos los requisitos de seguridad.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Requisitos de Contraseña en tiempo real
                    _buildRequirementRow('Mínimo 8 caracteres', _hasMinLength),
                    _buildRequirementRow('Al menos una letra (A-Z / a-z)', _hasLetter),
                    _buildRequirementRow('Al menos un número (0-9)', _hasNumber),
                    const SizedBox(height: 24),

                    // Selector de Banda
                    Text(
                      'Banda Wi-Fi a Configurar',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: '2.4GHz', label: Text('2.4 GHz'), icon: Icon(Icons.wifi_1_bar)),
                        ButtonSegment(value: '5GHz', label: Text('5 GHz'), icon: Icon(Icons.wifi_channel)),
                        ButtonSegment(value: 'dual', label: Text('Ambas (Dual)'), icon: Icon(Icons.router)),
                      ],
                      selected: {_selectedBand},
                      onSelectionChanged: isLoading
                          ? null
                          : (newSelection) {
                              setState(() {
                                _selectedBand = newSelection.first;
                              });
                            },
                    ),
                    const SizedBox(height: 32),

                    // Botón Guardar / Estado de Carga
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: isLoading
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) {
                                  context.read<WifiFormCubit>().updateCredentials(
                                        contractId: widget.contractId,
                                        ssid: _ssidController.text.trim(),
                                        password: _passwordController.text,
                                        band: _selectedBand,
                                      );
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                'Guardar Cambios en Router',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRequirementRow(String label, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel_outlined,
            size: 16,
            color: isMet ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? Colors.green.shade800 : Colors.grey.shade600,
              fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 56),
        title: const Text('¡Solicitud Enviada!'),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop(); // Volver a pantalla anterior
            },
            child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
