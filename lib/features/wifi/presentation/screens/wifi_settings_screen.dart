import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/wifi_network.dart';
import '../blocs/wifi_cubit.dart';

class WifiSettingsScreen extends StatefulWidget {
  const WifiSettingsScreen({super.key});

  @override
  State<WifiSettingsScreen> createState() => _WifiSettingsScreenState();
}

class _WifiSettingsScreenState extends State<WifiSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _ssid24Controller = TextEditingController();
  final _pass24Controller = TextEditingController();
  bool _enabled24 = true;

  final _ssid50Controller = TextEditingController();
  final _pass50Controller = TextEditingController();
  bool _enabled50 = true;

  bool _initialized = false;

  @override
  void dispose() {
    _ssid24Controller.dispose();
    _pass24Controller.dispose();
    _ssid50Controller.dispose();
    _pass50Controller.dispose();
    super.dispose();
  }

  void _initFields(WifiNetwork network) {
    if (!_initialized) {
      _ssid24Controller.text = network.ssid24;
      _pass24Controller.text = network.password24;
      _enabled24 = network.isEnabled24;
      
      _ssid50Controller.text = network.ssid50;
      _pass50Controller.text = network.password50;
      _enabled50 = network.isEnabled50;
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Configuración de Mi Wi-Fi"),
      ),
      body: BlocConsumer<WifiCubit, WifiState>(
        listener: (context, state) {
          if (state is WifiSubmitSuccessState) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("¡Red Wi-Fi actualizada con éxito en la ONT!"),
                backgroundColor: Colors.green,
              ),
            );
            _initialized = false; // Permitir reinicialización con nuevos datos
            context.read<WifiCubit>().loadSettings();
          } else if (state is WifiFailureState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is WifiLoadingState || state is WifiInitialState) {
            return const Center(child: CircularProgressIndicator());
          }

          WifiNetwork? network;
          if (state is WifiLoadSuccessState) {
            network = state.network;
            _initFields(network);
          } else if (state is WifiSubmitSuccessState) {
            network = state.network;
          } else if (state is WifiSubmittingState) {
            // Mostrar UI con progreso de guardado
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Aplicando cambios en la ONT residencial..."),
                ],
              ),
            );
          }

          if (network == null) {
            return Center(
              child: ElevatedButton(
                onPressed: () => context.read<WifiCubit>().loadSettings(),
                child: const Text("Reintentar Cargar"),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // CARD BANDA 2.4 GHz
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Frecuencia 2.4 GHz",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              Switch(
                                value: _enabled24,
                                onChanged: (value) {
                                  setState(() => _enabled24 = value);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_enabled24) ...[
                            TextFormField(
                              controller: _ssid24Controller,
                              decoration: const InputDecoration(
                                labelText: "Nombre de Red (SSID)",
                                prefixIcon: Icon(Icons.wifi),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return "El nombre de red es requerido";
                                }
                                if (val.length < 3) {
                                  return "Debe tener al menos 3 caracteres";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _pass24Controller,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: "Contraseña",
                                prefixIcon: Icon(Icons.lock),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return "La contraseña es requerida";
                                }
                                if (val.length < 8) {
                                  return "La contraseña debe tener al menos 8 caracteres";
                                }
                                return null;
                              },
                            ),
                          ] else
                            Text(
                              "Banda desactivada temporalmente.",
                              style: TextStyle(color: theme.disabledColor),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // CARD BANDA 5 GHz
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Frecuencia 5 GHz (Alta Velocidad)",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              Switch(
                                value: _enabled50,
                                onChanged: (value) {
                                  setState(() => _enabled50 = value);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_enabled50) ...[
                            TextFormField(
                              controller: _ssid50Controller,
                              decoration: const InputDecoration(
                                labelText: "Nombre de Red (SSID)",
                                prefixIcon: Icon(Icons.wifi_tethering),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return "El nombre de red es requerido";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _pass50Controller,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: "Contraseña",
                                prefixIcon: Icon(Icons.lock),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return "La contraseña es requerida";
                                }
                                if (val.length < 8) {
                                  return "La contraseña debe tener al menos 8 caracteres";
                                }
                                return null;
                              },
                            ),
                          ] else
                            Text(
                              "Banda desactivada temporalmente.",
                              style: TextStyle(color: theme.disabledColor),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // BOTÓN GUARDAR
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final updated = WifiNetwork(
                          ssid24: _ssid24Controller.text,
                          password24: _pass24Controller.text,
                          isEnabled24: _enabled24,
                          ssid50: _ssid50Controller.text,
                          password50: _pass50Controller.text,
                          isEnabled50: _enabled50,
                        );
                        context.read<WifiCubit>().updateSettings(updated);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Guardar Cambios",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
