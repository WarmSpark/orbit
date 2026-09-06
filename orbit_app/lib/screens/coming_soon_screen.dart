import 'package:flutter/material.dart';

import '../theme.dart';
import 'splash_screen.dart';

class ComingSoonScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const ComingSoonScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5B6EF5), Color(0xFF9B7CF8)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const OrbitMark(size: 96),
                const SizedBox(height: 32),
                const Text(
                  'The Orbit is\ncoming soon…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Orbit is only live in the Delhi NCR right now. '
                  'We could not find you inside the zone — hang tight, '
                  'we are expanding soon!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: OrbitColors.primary,
                    ),
                    child: const Text('Check my location again'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
