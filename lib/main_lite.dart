import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/lite_chat_screen.dart';
import 'screens/login_screen.dart';
import 'services/Jarvis_api.dart';

void main() {
  runApp(const JarvisLiteApp());
}

class JarvisLiteApp extends StatefulWidget {
  const JarvisLiteApp({super.key});

  @override
  State<JarvisLiteApp> createState() => _JarvisLiteAppState();
}

class _JarvisLiteAppState extends State<JarvisLiteApp> {
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
      final loggedIn = await _api.isLoggedIn();
      if (!mounted) return;

      setState(() {
        _authenticated = loggedIn;
        _checkingSession = false;
      });

      if (loggedIn) unawaited(_syncDevice());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _authenticated = false;
        _checkingSession = false;
      });
    }
  }

  Future<void> _syncDevice() async {
    try {
      await _api.heartbeatDevice();
    } catch (_) {
      // A heartbeat failure must not prevent the chat from opening.
    }
  }

  void _onLoginSuccess() {
    setState(() => _authenticated = true);
    unawaited(_syncDevice());
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    setState(() => _authenticated = false);
  }

  Widget _home() {
    if (_checkingSession) {
      return const Scaffold(
        backgroundColor: Color(0xFF050A0F),
        body: Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    }

    if (_authenticated) {
      return LiteChatScreen(api: _api, onLogout: _logout);
    }

    return LoginScreen(api: _api, onLoginSuccess: _onLoginSuccess);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'J.A.R.V.I.S. Lite',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050A0F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
        ),
      ),
      home: _home(),
    );
  }
}
