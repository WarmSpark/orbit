import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'screens/coming_soon_screen.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..bootstrap(),
      child: const OrbitApp(),
    ),
  );
}

class OrbitApp extends StatelessWidget {
  const OrbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppState>().themeMode;
    return MaterialApp(
      title: 'Orbit',
      debugShowCheckedModeBanner: false,
      theme: buildOrbitTheme(Brightness.light),
      darkTheme: buildOrbitTheme(Brightness.dark),
      themeMode: mode,
      home: const _SystemOverlay(child: RootGate()),
    );
  }
}

class _SystemOverlay extends StatelessWidget {
  final Widget child;
  const _SystemOverlay({required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: child,
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AppState>().status;
    switch (status) {
      case AuthStatus.unknown:
        return const SplashScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.onboarding:
        return const OnboardingScreen();
      case AuthStatus.authenticated:
        return const LocationGate();
    }
  }
}

class LocationGate extends StatefulWidget {
  const LocationGate({super.key});

  @override
  State<LocationGate> createState() => _LocationGateState();
}

enum _Phase { checking, inside, outside }

class _LocationGateState extends State<LocationGate> {
  _Phase _phase = _Phase.checking;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();

    if (app.isInNCR) {
      _phase = _Phase.inside;
    } else {
      _check();
    }
  }

  Future<void> _check() async {
    setState(() => _phase = _Phase.checking);
    final app = context.read<AppState>();
    final result = await app.location.current();
    if (!mounted) return;
    if (result.isOk) {
      app.setLocation(result.position!);
      final inside = Config.withinNCR(
        result.position!.latitude,
        result.position!.longitude,
      );
      if (inside) {
        setState(() => _phase = _Phase.inside);
        return;
      }
    }

    if (Config.devAuthEnabled) {
      app.setLocation(const LatLng(Config.ncrCenterLat, Config.ncrCenterLng));
      setState(() => _phase = _Phase.inside);
      return;
    }
    setState(() => _phase = _Phase.outside);
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.checking:
        return const SplashScreen();
      case _Phase.inside:
        return const HomeShell();
      case _Phase.outside:
        return ComingSoonScreen(onRetry: _check);
    }
  }
}
