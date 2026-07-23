import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../data/services/network_health_checker.dart';
import '../cubit/network_health_cubit.dart';
import '../cubit/network_health_state.dart';

class NetworkHealthScreen extends StatelessWidget {
  const NetworkHealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NetworkHealthCubit(
        checker: NetworkHealthChecker(
          networkInfo: NetworkInfo(),
          dio: Dio(BaseOptions(baseUrl: 'https://api.isp-backend.com/v1')),
        ),
      )..runDiagnostic(),
      child: const _NetworkHealthView(),
    );
  }
}

class _NetworkHealthView extends StatelessWidget {
  const _NetworkHealthView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salud de la Conexión'),
        centerTitle: true,
      ),
      body: BlocBuilder<NetworkHealthCubit, NetworkHealthState>(
        builder: (context, state) {
          final isLoading = state is NetworkHealthLoading;

          if (state is NetworkHealthNoWifi) {
            return _buildNoWifiWarning(context, state.message);
          }

          if (state is NetworkHealthError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text(state.errorMessage, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.read<NetworkHealthCubit>().runDiagnostic(),
                      child: const Text('Reintentar Diagnóstico'),
                    ),
                  ],
                ),
              ),
            );
          }

          final result = (state is NetworkHealthSuccess) ? state.result : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAlignment.stretch,
              children: [
                // 1. TARJETA PRINCIPAL SEMÁFORO
                _buildTrafficLightCard(context, result, isLoading),
                const SizedBox(height: 24),

                // 2. PANEL DE MÉTRICAS CLARAS
                Text(
                  'Métricas de Conexión',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildMetricsPanel(context, result, isLoading),
                const SizedBox(height: 24),

                // 3. BLOQUE DE SUGERENCIAS INTELIGENTES
                Text(
                  'Sugerencias Inteligentes',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildSmartSuggestions(context, result, isLoading),
                const SizedBox(height: 32),

                // 4. BOTÓN DE ACCIÓN CON ANIMACIÓN
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isLoading
                        ? null
                        : () => context.read<NetworkHealthCubit>().runDiagnostic(),
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(
                      isLoading ? 'Ejecutando Diagnóstico...' : 'Ejecutar Diagnóstico',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Estado preventivo sin Wi-Fi
  Widget _buildNoWifiWarning(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, size: 72, color: Colors.orange.shade800),
            ),
            const SizedBox(height: 24),
            Text(
              'Sin Conexión Wi-Fi',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.read<NetworkHealthCubit>().runDiagnostic(),
              icon: const Icon(Icons.refresh),
              label: const Text('Recomprobar Conexión'),
            ),
          ],
        ),
      ),
    );
  }

  // Tarjeta Semáforo
  Widget _buildTrafficLightCard(
    BuildContext context,
    NetworkHealthResult? result,
    bool isLoading,
  ) {
    Color cardColor = Colors.grey.shade100;
    Color iconColor = Colors.grey;
    IconData icon = Icons.sensors;
    String statusTitle = 'Evaluando Conexión...';
    String statusSubtitle = 'Por favor espera mientras analizamos tu red.';

    if (isLoading) {
      cardColor = Colors.blue.shade50;
      iconColor = Colors.blue;
      icon = Icons.sync;
      statusTitle = 'Analizando Red...';
      statusSubtitle = 'Probando Wi-Fi, salida WAN y estado del sector.';
    } else if (result != null) {
      if (result.isOverallGreen) {
        cardColor = Colors.green.shade50;
        iconColor = Colors.green.shade700;
        icon = Icons.check_circle;
        statusTitle = 'Conexión Óptima';
        statusSubtitle = 'Tu servicio opera al 100% sin degradación ni incidencias.';
      } else if (result.isOverallRed) {
        cardColor = Colors.red.shade50;
        iconColor = Colors.red.shade700;
        icon = Icons.error;
        statusTitle = 'Atención Requerida';
        statusSubtitle = 'Se detectaron fallos críticos en la salida o en tu sector.';
      } else {
        cardColor = Colors.amber.shade50;
        iconColor = Colors.amber.shade800;
        icon = Icons.warning_amber_rounded;
        statusTitle = 'Conexión Inestable';
        statusSubtitle = 'Existe una ligera degradación de velocidad o latencia.';
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusSubtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Panel de Métricas Claras
  Widget _buildMetricsPanel(
    BuildContext context,
    NetworkHealthResult? result,
    bool isLoading,
  ) {
    if (isLoading || result == null) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(child: LinearProgressIndicator()),
        ),
      );
    }

    final wifiLatencyStr =
        result.wifiLatencyMs > 900 ? 'Sin respuesta' : '${result.wifiLatencyMs} ms';

    String wanText = 'Excelente';
    Color wanColor = Colors.green;
    if (result.wanStatus == WanStatus.degraded) {
      wanText = 'Degradada';
      wanColor = Colors.orange;
    } else if (result.wanStatus == WanStatus.offline) {
      wanText = 'Sin Internet';
      wanColor = Colors.red;
    }

    String sectorText = 'Operativo';
    Color sectorColor = Colors.green;
    if (result.sectorStatus == SectorStatus.incidentReported) {
      sectorText = 'Avería Masiva';
      sectorColor = Colors.red;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildMetricItem(
              icon: Icons.wifi,
              label: 'Latencia Wi-Fi Local',
              value: wifiLatencyStr,
              valueColor: result.wifiStatus == WifiStatus.optimal ? Colors.green : Colors.orange,
            ),
            const Divider(),
            _buildMetricItem(
              icon: Icons.public,
              label: 'Calidad de Salida WAN',
              value: wanText,
              valueColor: wanColor,
            ),
            const Divider(),
            _buildMetricItem(
              icon: Icons.location_city,
              label: 'Estado del Sector / Barrio',
              value: sectorText,
              valueColor: sectorColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: valueColor),
          ),
        ],
      ),
    );
  }

  // Sugerencias Inteligentes
  Widget _buildSmartSuggestions(
    BuildContext context,
    NetworkHealthResult? result,
    bool isLoading,
  ) {
    if (isLoading || result == null) {
      return const SizedBox.shrink();
    }

    final List<Widget> suggestions = [];

    if (result.sectorStatus == SectorStatus.incidentReported) {
      suggestions.add(_buildSuggestionTile(
        icon: Icons.engineering,
        title: 'Incidencia en tu zona',
        description: result.sectorMessage,
        color: Colors.red,
      ));
    }

    if (result.wifiStatus == WifiStatus.unstable) {
      suggestions.add(_buildSuggestionTile(
        icon: Icons.router,
        title: 'Wi-Fi Inestable',
        description:
            'Te sugerimos acercarte al router o cambiar a la frecuencia 5 GHz en tu configuración Wi-Fi.',
        color: Colors.orange,
      ));
    }

    if (result.wanStatus == WanStatus.offline &&
        result.sectorStatus != SectorStatus.incidentReported) {
      suggestions.add(_buildSuggestionTile(
        icon: Icons.power_settings_new,
        title: 'Sin Acceso a Internet',
        description:
            'Intenta reiniciar tu Router/ONT desconectando el cable de energía por 10 segundos.',
        color: Colors.red,
      ));
    }

    if (result.isOverallGreen) {
      suggestions.add(_buildSuggestionTile(
        icon: Icons.thumb_up,
        title: 'Todo se ve excelente',
        description: 'No se requieren acciones. Disfruta de tu navegación a alta velocidad.',
        color: Colors.green,
      ));
    }

    return Column(children: suggestions);
  }

  Widget _buildSuggestionTile({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
