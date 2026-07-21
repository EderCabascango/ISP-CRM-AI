import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/devices_bloc.dart';
import '../../domain/entities/connected_device.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dispositivos Conectados"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DevicesBloc>().add(FetchDevicesEvent()),
          ),
        ],
      ),
      body: BlocBuilder<DevicesBloc, DevicesState>(
        builder: (context, state) {
          if (state is DevicesInitialState || state is DevicesLoadingState) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is DevicesFailureState) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Ocurrió un error: ${state.errorMessage}"),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.read<DevicesBloc>().add(FetchDevicesEvent()),
                    child: const Text("Reintentar"),
                  ),
                ],
              ),
            );
          }

          if (state is DevicesLoadSuccessState) {
            return Column(
              children: [
                // Chips de Filtro
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: "Todos (${state.allDevices.length})",
                          selected: state.activeFilter == DeviceFilter.all,
                          onSelected: () => context
                              .read<DevicesBloc>()
                              .add(const ChangeFilterEvent(DeviceFilter.all)),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: "Wi-Fi",
                          selected: state.activeFilter == DeviceFilter.wifi,
                          onSelected: () => context
                              .read<DevicesBloc>()
                              .add(const ChangeFilterEvent(DeviceFilter.wifi)),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: "Cableados (LAN)",
                          selected: state.activeFilter == DeviceFilter.lan,
                          onSelected: () => context
                              .read<DevicesBloc>()
                              .add(const ChangeFilterEvent(DeviceFilter.lan)),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Lista de Dispositivos
                Expanded(
                  child: state.filteredDevices.isEmpty
                      ? const Center(child: Text("No hay dispositivos en esta categoría."))
                      : ListView.builder(
                          itemCount: state.filteredDevices.length,
                          itemBuilder: (context, index) {
                            final device = state.filteredDevices[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: device.isOnline
                                      ? theme.colorScheme.primaryContainer
                                      : theme.disabledColor.withOpacity(0.2),
                                  child: Icon(
                                    device.interfaceType == DeviceInterfaceType.lan
                                        ? Icons.settings_ethernet
                                        : Icons.wifi,
                                    color: device.isOnline
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.disabledColor,
                                  ),
                                ),
                                title: Text(
                                  device.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("IP: ${device.ipAddress} | MAC: ${device.macAddress}"),
                                    Text(
                                      device.interfaceLabel,
                                      style: TextStyle(
                                        color: theme.colorScheme.secondary,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: device.isOnline
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    device.isOnline ? "Online" : "Offline",
                                    style: TextStyle(
                                      color: device.isOnline ? Colors.green : Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
