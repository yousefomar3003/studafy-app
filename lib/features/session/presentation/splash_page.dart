import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/studafy_design.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    // No fixed wait: the role screen shows the same mark while it decides
    // whether a session can go straight back in, so holding here only adds
    // time to every launch.
    timer = Timer(Duration.zero, () {
      if (mounted) {
        // Named route so the app supplies the session dependencies; the
        // splash stays dependency-free.
        Navigator.pushReplacementNamed(context, '/roles');
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => const AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: studafyAbyss,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: studafyOceanGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StudafyLogo(size: 64, onDark: true),
              SizedBox(height: 18),
              Text(
                'School life, connected.',
                style: TextStyle(color: studafyFrost, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
