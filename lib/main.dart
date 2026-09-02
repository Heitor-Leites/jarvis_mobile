
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'screens/login_screen.dart';
import 'services/jarvis_api.dart';

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
  bool _loggedIn = false;

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
        _loggedIn = loggedIn;
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
        _loggedIn = false;
        _checkingSession = false;
      });
    }
  }

  void _handleLoginSuccess() {
    setState(() {
      _loggedIn = true;
    });
  }

  Future<void> _handleLogout() async {
    await _api.logout();

    if (!mounted) {
      return;
    }

    setState(() {
      _loggedIn = false;
    });
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
      home: _checkingSession
          ? const _LoadingScreen()
          : _loggedIn
              ? JarvisHome(
                  api: _api,
                  onLogout: _handleLogout,
                )
              : LoginScreen(
                  api: _api,
                  onLoginSuccess: _handleLoginSuccess,
                ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF050A0F),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.cyanAccent,
              ),
            ),
            SizedBox(height: 18),
            Text(
              'J.A.R.V.I.S.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'INICIALIZANDO...',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JarvisHome extends StatefulWidget {
  const JarvisHome({
    super.key,
    required this.api,
    required this.onLogout,
  });

  final JarvisApi api;
  final Future<void> Function() onLogout;

  @override
  State<JarvisHome> createState() => _JarvisHomeState();
}

class _JarvisHomeState extends State<JarvisHome> {
  final TextEditingController _controller =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  final stt.SpeechToText _speech =
      stt.SpeechToText();

  final FlutterTts _tts = FlutterTts();

  final List<Map<String, String>> _messages = [];

  bool _isLoading = false;
  bool _microphoneActive = false;
  bool _speechAvailable = false;
  bool _wakingUpServer = false;

  Timer? _wakingUpTimer;

  static const Duration _wakingUpThreshold =
      Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    _initializeVoice();
  }

  Future<void> _initializeVoice() async {
    try {
      await _tts.setLanguage('pt-BR');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(0.9);

      final bool available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) {
            return;
          }

          if (status == 'done' ||
              status == 'notListening') {
            setState(() {
              _microphoneActive = false;
            });
          }
        },
        onError: (error) {
          if (!mounted) {
            return;
          }

          setState(() {
            _microphoneActive = false;
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _speechAvailable = available;
      });
    } catch (error) {
      debugPrint(
        'Erro ao inicializar voz: $error',
      );
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable || _isLoading) {
      return;
    }

    if (_speech.isListening) {
      await _speech.stop();

      if (!mounted) {
        return;
      }

      setState(() {
        _microphoneActive = false;
      });

      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _microphoneActive = true;
    });

    try {
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: 'pt_BR',
        ),
        onResult: (result) {
          if (!mounted) {
            return;
          }

          setState(() {
            _controller.text =
                result.recognizedWords;

            _controller.selection =
                TextSelection.fromPosition(
              TextPosition(
                offset: _controller.text.length,
              ),
            );
          });

          if (result.finalResult) {
            _speech.stop();

            if (!mounted) {
              return;
            }

            setState(() {
              _microphoneActive = false;
            });

            if (_controller.text.trim().isNotEmpty) {
              _sendMessage(
                fromMicrophone: true,
              );
            }
          }
        },
      );
    } catch (error) {
      debugPrint(
        'Erro no microfone: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _microphoneActive = false;
      });
    }
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) {
      return;
    }

    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (error) {
      debugPrint(
        'Erro no TTS: $error',
      );
    }
  }

  Future<void> _addErrorMessage(
    String text,
    bool fromMicrophone,
  ) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _messages.add({
        'sender': 'JARVIS',
        'message': text,
      });
    });

    _scrollToBottom();

    if (fromMicrophone) {
      await _speak(text);
    }
  }

  Future<void> _sendMessage({
    bool fromMicrophone = false,
  }) async {
    final String message =
        _controller.text.trim();

    final bool shouldSpeak = message
        .toLowerCase()
        .startsWith('/falar');

    final String cleanMessage = shouldSpeak
        ? message.substring(6).trim()
        : message;

    if (cleanMessage.isEmpty || _isLoading) {
      return;
    }

    setState(() {
      _messages.add({
        'sender': 'Você',
        'message': cleanMessage,
      });

      _controller.clear();
      _isLoading = true;
      _wakingUpServer = false;
    });

    _scrollToBottom();

    _wakingUpTimer?.cancel();

    _wakingUpTimer = Timer(
      _wakingUpThreshold,
      () {
        if (!mounted) {
          return;
        }

        if (_isLoading) {
          setState(() {
            _wakingUpServer = true;
          });
        }
      },
    );

    try {
      final Stopwatch timer =
          Stopwatch()..start();

      debugPrint(
        '========== JARVIS ==========',
      );

      debugPrint(
        'Mensagem recebida: $cleanMessage',
      );

      debugPrint(
        'Enviando para o backend...',
      );

      final String answer =
          await widget.api.chat(
        message: cleanMessage,
      );

      debugPrint(
        'Resposta recebida em '
        '${timer.elapsedMilliseconds} ms.',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add({
          'sender': 'JARVIS',
          'message': answer,
        });
      });

      _scrollToBottom();

      if (fromMicrophone || shouldSpeak) {
        await _speak(answer);
      }
    } on TimeoutException catch (error) {
      debugPrint(
        '========== ERRO TIMEOUT ==========',
      );

      debugPrint(error.toString());

      debugPrint(
        '=================================',
      );

      await _addErrorMessage(
        'O servidor demorou demais para responder. '
        'Ele pode estar acordando depois de um período '
        'inativo. Tente novamente em alguns segundos.',
        fromMicrophone,
      );
    } catch (error) {
      final String errorText =
          error.toString();

      debugPrint(
        '========== ERRO JARVIS ==========',
      );

      debugPrint(errorText);

      debugPrint(
        '================================',
      );

      if (errorText.contains('SESSION_EXPIRED') ||
          errorText.contains('NOT_AUTHENTICATED')) {
        await _addErrorMessage(
          'Sua sessão expirou. Faça login novamente.',
          fromMicrophone,
        );

        await widget.onLogout();

        return;
      }

      if (errorText.contains('401')) {
        await _addErrorMessage(
          'Acesso não autorizado. Faça login novamente.',
          fromMicrophone,
        );
      } else if (errorText.contains('SERVICE_UNAVAILABLE')) {
        await _addErrorMessage(
          'O serviço do Gemini está temporariamente '
          'indisponível. Tente novamente em instantes.',
          fromMicrophone,
        );
      } else if (errorText.contains('VALIDATION_ERROR')) {
        await _addErrorMessage(
          'A mensagem enviada não foi aceita pelo servidor.',
          fromMicrophone,
        );
      } else if (errorText.contains('SERVER_ERROR')) {
        await _addErrorMessage(
          'O servidor teve um problema ao consultar a IA.',
          fromMicrophone,
        );
      } else {
        await _addErrorMessage(
          'Não foi possível falar com o servidor. '
          'Tente novamente em instantes.',
          fromMicrophone,
        );
      }
    } finally {
      _wakingUpTimer?.cancel();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _wakingUpServer = false;
        });

        _scrollToBottom();
      }
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!_scrollController.hasClients) {
          return;
        }

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(
            milliseconds: 300,
          ),
          curve: Curves.easeOut,
        );
      },
    );
  }

  Widget _buildStatus(
    String name,
    bool active,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? Colors.cyanAccent
                : Colors.grey,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.cyan.withValues(
                        alpha: 0.6,
                      ),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          name,
          style: TextStyle(
            color: active
                ? Colors.white70
                : Colors.white38,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(
    Map<String, String> message,
  ) {
    final bool isUser =
        message['sender'] == 'Você';

    return Align(
      alignment: isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 330,
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.cyan.withValues(
                  alpha: 0.18,
                )
              : Colors.white.withValues(
                  alpha: 0.07,
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUser
                ? Colors.cyan.withValues(
                    alpha: 0.5,
                  )
                : Colors.white.withValues(
                    alpha: 0.12,
                  ),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              message['sender'] ?? '',
              style: TextStyle(
                color: isUser
                    ? Colors.cyanAccent
                    : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message['message'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    if (_isLoading) {
      return;
    }

    await widget.onLogout();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _wakingUpTimer?.cancel();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Column(
          children: [
            Text(
              'J.A.R.V.I.S.',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            Text(
              'SISTEMA ONLINE',
              style: TextStyle(
                color:
                    Colors.cyanAccent,
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _clearChat,
            icon: const Icon(
              Icons.delete_outline,
            ),
            tooltip:
                'Limpar conversa',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(
              Icons.logout,
            ),
            tooltip:
                'Sair',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration:
                                BoxDecoration(
                              shape:
                                  BoxShape.circle,
                              border: Border.all(
                                color: Colors
                                    .cyanAccent,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors
                                      .cyan
                                      .withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons
                                  .smart_toy_outlined,
                              color:
                                  Colors.cyanAccent,
                              size: 55,
                            ),
                          ),
                          const SizedBox(
                            height: 25,
                          ),
                          const Text(
                            'Olá, senhor.',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          const Text(
                            'Como posso ajudá-lo?',
                            style: TextStyle(
                              color:
                                  Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          const Padding(
                            padding:
                                EdgeInsets
                                    .symmetric(
                              horizontal: 30,
                            ),
                            child: Text(
                              'Digite um comando abaixo '
                              'ou use o microfone.',
                              textAlign:
                                  TextAlign.center,
                              style: TextStyle(
                                color:
                                    Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller:
                          _scrollController,
                      itemCount:
                          _messages.length,
                      padding:
                          const EdgeInsets.only(
                        top: 10,
                        bottom: 10,
                      ),
                      itemBuilder:
                          (context, index) {
                        return _buildMessage(
                          _messages[index],
                        );
                      },
                    ),
            ),
            if (_isLoading)
              Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 8,
                ),
                child: Text(
                  _wakingUpServer
                      ? 'Acordando o servidor, '
                        'pode levar alguns segundos...'
                      : 'JARVIS está processando...',
                  style: const TextStyle(
                    color:
                        Colors.cyanAccent,
                    fontSize: 12,
                  ),
                ),
              ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 30,
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                children: [
                  _buildStatus(
                    'IA',
                    true,
                  ),
                  _buildStatus(
                    'MIC',
                    _microphoneActive,
                  ),
                  _buildStatus(
                    'SISTEMA',
                    true,
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                0,
                12,
                12,
              ),
              child: TextField(
                controller:
                    _controller,
                textInputAction:
                    TextInputAction.send,
                onSubmitted: (_) {
                  _sendMessage();
                },
                decoration:
                    InputDecoration(
                  hintText:
                      'Digite um comando...',
                  filled: true,
                  fillColor: Colors
                      .white
                      .withValues(
                    alpha: 0.06,
                  ),
                  prefixIcon:
                      IconButton(
                    onPressed:
                        _startListening,
                    icon: Icon(
                      _microphoneActive
                          ? Icons.mic
                          : Icons.mic_none,
                      color:
                          _microphoneActive
                              ? Colors.cyanAccent
                              : Colors.white70,
                    ),
                  ),
                  suffixIcon:
                      IconButton(
                    onPressed:
                        _isLoading
                            ? null
                            : _sendMessage,
                    icon:
                        const Icon(
                      Icons.arrow_upward,
                      color:
                          Colors.cyanAccent,
                    ),
                  ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
