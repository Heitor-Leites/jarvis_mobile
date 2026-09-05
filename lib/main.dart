import 'package:flutter/material.dart';

import 'package:jarvis_mobile/screens/dashboard_screens.dart';
import 'package:jarvis_mobile/screens/Login_screen.dart';
import 'package:jarvis_mobile/services/Jarvis_api.dart';

void main() {
  runApp(const JarvisApp());
}

class JarvisApp extends StatefulWidget {
  const JarvisApp({super.key});

  @override
  State<JarvisApp> createState() => _JarvisAppState();
}

class _JarvisAppState extends State<JarvisApp> {
  late final JarvisApi _api;

  bool _checkingSession = true;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();

    _api = JarvisApi(
      baseUrl: 'https://jarvis-backend-mzhe.onrender.com',
    );

    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final bool loggedIn = await _api.isLoggedIn();

      if (!mounted) {
        return;
      }

      setState(() {
        _authenticated = loggedIn;
        _checkingSession = false;
      });
    } catch (error) {
      debugPrint(
        'Erro ao verificar sessão: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _authenticated = false;
        _checkingSession = false;
      });
    }
  }

  void _handleLoginSuccess() {
    setState(() {
      _authenticated = true;
    });
  }

  void _handleLogout() {
    setState(() {
      _authenticated = false;
    });
  }

  Widget _buildHome() {
    if (_checkingSession) {
      return const Scaffold(
        backgroundColor: Color(0xFF050A0F),
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.cyanAccent,
          ),
        ),
      );
    }

    if (_authenticated) {
      return DashboardScreen(
        api: _api,
        onLogout: _handleLogout,
      );
    }

    return LoginScreen(
      api: _api,
      onLoginSuccess: _handleLoginSuccess,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'J.A.R.V.I.S.',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050A0F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
        ),
      ),
      home: _buildHome(),
    );
  }
}