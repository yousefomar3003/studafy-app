import 'dart:async';

import 'package:flutter/material.dart';

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
    timer = Timer(const Duration(seconds: 2), () {
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
  Widget build(BuildContext c) => const Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StudafyLogo(size: 64),
          SizedBox(height: 18),
          Text(
            'School life, connected.',
            style: TextStyle(color: studafyMuted, fontSize: 16),
          ),
        ],
      ),
    ),
  );
}
