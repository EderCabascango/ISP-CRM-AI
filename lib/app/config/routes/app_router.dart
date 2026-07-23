import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/auth/presentation/screens/login_screen.dart';
import '../../../features/home/presentation/screens/home_screen.dart';
import '../../../features/wifi/presentation/screens/wifi_settings_screen.dart';
import '../../../features/wifi_management/presentation/screens/wifi_credentials_screen.dart';
import '../../../features/devices/presentation/screens/devices_screen.dart';
import '../../../features/connected_devices/presentation/screens/connected_devices_screen.dart';
import '../../../features/network_health/presentation/screens/network_health_screen.dart';
import '../../../features/speedtest_optimization/presentation/screens/speedtest_screen.dart';
import '../../../features/account_billing/presentation/screens/account_billing_screen.dart';
import '../../../features/auth/presentation/blocs/auth_bloc.dart';
import '../../../features/wifi/presentation/blocs/wifi_cubit.dart';
import '../../../features/devices/presentation/blocs/devices_bloc.dart';

GoRouter createAppRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _BlocRefreshListenable(authBloc),
    redirect: (context, state) {
      final authState = authBloc.state;
      final loggingIn = state.matchedLocation == '/login';

      if (authState is UnauthenticatedState) {
        return '/login';
      }
      if (authState is AuthenticatedState) {
        if (loggingIn) return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/wifi',
        builder: (context, state) => BlocProvider.value(
          value: context.read<WifiCubit>()..loadSettings(),
          child: const WifiSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/wifi-credentials',
        builder: (context, state) => const WifiCredentialsScreen(),
      ),
      GoRoute(
        path: '/devices',
        builder: (context, state) => BlocProvider.value(
          value: context.read<DevicesBloc>()..add(FetchDevicesEvent()),
          child: const DevicesScreen(),
        ),
      ),
      GoRoute(
        path: '/network-health',
        builder: (context, state) => const NetworkHealthScreen(),
      ),
      GoRoute(
        path: '/connected-devices',
        builder: (context, state) => const ConnectedDevicesScreen(),
      ),
      GoRoute(
        path: '/speedtest',
        builder: (context, state) => const SpeedtestScreen(),
      ),
      GoRoute(
        path: '/account-billing',
        builder: (context, state) => const AccountBillingScreen(),
      ),
    ],
  );
}

// Convertidor de cambios de BLoC a Listenable para go_router
class _BlocRefreshListenable extends ChangeNotifier {
  late final dynamic _subscription;

  _BlocRefreshListenable(Bloc bloc) {
    _subscription = bloc.stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
