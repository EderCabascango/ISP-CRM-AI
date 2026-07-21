import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app/di/injection.dart';
import 'app/config/routes/app_router.dart';
import 'features/auth/presentation/blocs/auth_bloc.dart';
import 'features/wifi/presentation/blocs/wifi_cubit.dart';
import 'features/devices/presentation/blocs/devices_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa la Inyección de Dependencias manual
  await initDI();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => locator<AuthBloc>()..add(CheckAuthSessionEvent()),
        ),
        BlocProvider<WifiCubit>(
          create: (_) => locator<WifiCubit>(),
        ),
        BlocProvider<DevicesBloc>(
          create: (_) => locator<DevicesBloc>(),
        ),
      ],
      child: Builder(
        builder: (context) {
          final authBloc = context.read<AuthBloc>();
          final router = createAppRouter(authBloc);

          return MaterialApp.router(
            title: 'ISP WiFi Manager',
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0F4C81), // Azul clásico/profundo de ISP
                brightness: Brightness.light,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.grey.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0F4C81),
                brightness: Brightness.dark,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            themeMode: ThemeMode.system, // Cambia automáticamente según el tema del sistema
            routerConfig: router,
          );
        },
      ),
    );
  }
}
