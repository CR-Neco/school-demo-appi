import 'package:flutter/material.dart';

import '../config.dart';
import 'components.dart';

/// The artwork is decorative; the original school logo stays a separate asset.
class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/branding/splash-students.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
          excludeFromSemantics: true,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xE6FFFFFA), Color(0xA6FFFFFA), Color(0x00FFFFFA)],
              stops: [0, 0.38, 0.75],
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 44),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/branding/pmg-logo.png',
                      semanticLabel: 'Philipp-Melanchthon-Gymnasium Meine – PMG-Logo',
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      AppConfig.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ink, fontSize: 42, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 22),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Color(0xFF531583), strokeWidth: 2),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Jahrgang wird geladen …',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
