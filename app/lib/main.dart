import 'package:flutter/material.dart';

import 'api.dart';
import 'config.dart';
import 'fundraising.dart';
import 'screens/home.dart';
import 'widgets/components.dart';
import 'widgets/school_artwork.dart';

void main() => runApp(const AppiApp());

class AppiApp extends StatefulWidget {
  const AppiApp({super.key, this.api});
  final AppiApi? api;
  @override
  State<AppiApp> createState() => _AppiAppState();
}

class _AppiAppState extends State<AppiApp> with WidgetsBindingObserver {
  late final AppiApi _api;
  SchoolConfig? _config;
  String? _error;
  bool _initial = true;
  bool _loading = false;
  Fundraising? _dashboard;
  String? _dashboardError;
  bool _dashboardLoading = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api = widget.api ?? LocalApi();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([_loadConfig(), _refreshDashboard()]);
  }

  Future<void> _loadConfig() async {
    if (!mounted || _loading) return;
    setState(() { _loading = true; });
    try {
      final config = await _api.loadConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _error = null;
        _initial = false;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiFailure
            ? error.message
            : 'Backend konnte nicht geladen werden.';
        _initial = false;
        _loading = false;
      });
    }
  }

  Future<void> _refreshDashboard() async {
    if (!mounted || _dashboardLoading) return;
    setState(() { _dashboardLoading = true; _dashboardError = null; });
    try {
      final dashboard = await _api.loadDashboard();
      if (!mounted) return;
      setState(() { _dashboard = dashboard; _dashboardLoading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _dashboard = null;
        _dashboardError = error is ApiFailure ? error.message : 'Finanzierungsstand konnte nicht geladen werden.';
        _dashboardLoading = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_initial) {
      _refreshDashboard();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: AppConfig.name,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF6F6F0),
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        primary: ink,
        surface: const Color(0xFFFFFEFA),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6F6F0),
        foregroundColor: ink,
      ),
    ),
    home: _initial
        ? const _Splash()
        : HomeScreen(
            config: _config,
            error: _error,
            loading: _loading,
            onRetry: _load,
            dashboard: _dashboard,
            dashboardError: _dashboardError,
            dashboardLoading: _dashboardLoading,
            onRefreshDashboard: _refreshDashboard,
          ),
  );
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ink,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 210,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: const SchoolArtwork(),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                AppConfig.name,
                style: TextStyle(
                  color: accent,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                AppConfig.tagline,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 14),
              const Text('Abiturjahrgang ${AppConfig.year}', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              const Text(
                AppConfig.school,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 26),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(color: accent, strokeWidth: 2),
              ),
              const SizedBox(height: 12),
              const Text(
                'Jahrgang wird geladen …',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        )),
      ),
    ),
  );
}
