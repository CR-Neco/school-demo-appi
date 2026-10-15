import 'package:flutter/material.dart';

import 'api.dart';
import 'config.dart';
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

class _AppiAppState extends State<AppiApp> {
  late final AppiApi _api;
  SchoolConfig? _config;
  String? _error;
  bool _initial = true;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _api = widget.api ?? LocalApi();
    _load();
  }

  Future<void> _load() async {
    if (!_initial)
      setState(() {
        _loading = true;
      });
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

  @override
  void dispose() {
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
        child: Padding(
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
        ),
      ),
    ),
  );
}
