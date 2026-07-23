import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/models/connected_device.dart';
import '../../data/repositories/connected_devices_repository_impl.dart';
import '../cubit/connected_devices_cubit.dart';

class ConnectedDevicesScreen extends StatelessWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ConnectedDevicesCubit(
        repository: ConnectedDevicesRepositoryImpl(
          dio: Dio(BaseOptions(baseUrl: 'https://api.isp-backend.com/v1')),
          secureStorage: const FlutterSecureStorage(),
        ),
      )..fetchDevices(),
      child: const _ConnectedDevicesView(),
    );
  }
}

class _ConnectedDevicesView extends StatelessWidget {
  const _ConnectedDevicesView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos Conectados'),
        centerTitle: true,
      ),
      body: BlocBuilder<ConnectedDevicesCubit, DevicesState>(
        builder: (context, state) {
          if (state is DevicesLoadingState || state is DevicesInitialState) {
            return _buildSkeletonLoading();
          }

          if (state is DevicesErrorState) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<ConnectedDevicesCubit>().fetchDevices(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final devices = (state is DevicesLoadedState) ? state.devices : <ConnectedDevice>[];

          if (devices.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => context.read<ConnectedDevicesCubit>().fetchDevices(),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.devices_other_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No hay dispositivos conectados',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<ConnectedDevicesCubit>().fetchDevices(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ENCABEZADO CON TOTAL
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.router_outlined, color: theme.colorScheme.onPrimaryContainer),
                      const SizedBox(width: 12),
                      Text(
                        '${devices.length} Dispositivos en red',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // LISTA DE TARJETAS DE DISPOSITIVOS
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final dev = devices[index];
                    return _buildDeviceCard(context, dev);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          height: 80,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(width: 48, height: 48, color: Colors.grey.shade300),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 140, height: 14, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Container(width: 100, height: 10, color: Colors.grey.shade200),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, ConnectedDevice device) {
    IconData typeIcon = Icons.wifi;
    String typeLabel = 'Wi-Fi 2.4 GHz';

    if (device.connectionType == ConnectionType.wifi5G) {
      typeIcon = Icons.wifi_channel;
      typeLabel = 'Wi-Fi 5.0 GHz';
    } else if (device.connectionType == ConnectionType.ethernet) {
      typeIcon = Icons.lan;
      typeLabel = 'Cable Ethernet';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            // Icono del tipo de conexión
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: device.isBlocked ? Colors.red.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                typeIcon,
                color: device.isBlocked ? Colors.red : Colors.blue.shade700,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),

            // Info Hostname / IP / MAC
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.hostname,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      decoration: device.isBlocked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'IP: ${device.ipAddress}  •  ${device.macAddress}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          typeLabel,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (device.signalStrength != null) ...[
                        const SizedBox(width: 8),
                        _buildSignalIcon(device.signalStrength!),
                        Text(
                          ' ${device.signalStrength} dBm',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Botón Pausar / Bloquear Internet
            Column(
              children: [
                Switch(
                  value: !device.isBlocked,
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.red,
                  onChanged: (active) {
                    context.read<ConnectedDevicesCubit>().toggleBlock(
                          device.macAddress,
                          device.isBlocked,
                        );
                  },
                ),
                Text(
                  device.isBlocked ? 'Pausado' : 'Activo',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: device.isBlocked ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalIcon(int dBm) {
    if (dBm >= -50) {
      return const Icon(Icons.signal_wifi_4_bar, size: 14, color: Colors.green);
    } else if (dBm >= -70) {
      return const Icon(Icons.network_wifi_3_bar, size: 14, color: Colors.orange);
    } else {
      return const Icon(Icons.network_wifi_1_bar, size: 14, color: Colors.red);
    }
  }
}
