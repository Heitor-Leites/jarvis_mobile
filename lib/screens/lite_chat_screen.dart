import 'package:flutter/material.dart';

import '../services/Jarvis_api.dart';

class LiteChatScreen extends StatefulWidget {
  const LiteChatScreen({
    super.key,
    required this.api,
    required this.onLogout,
  });

  final JarvisApi api;
  final Future<void> Function() onLogout;

  @override
  State<LiteChatScreen> createState() => _LiteChatScreenState();
}

class _LiteChatScreenState extends State<LiteChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_LiteMessage> _messages = [
    const _LiteMessage(
      text: 'Olá. Eu sou o JARVIS. Como posso ajudar você hoje?',
      fromUser: false,
    ),
  ];

  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    _controller.clear();
    setState(() {
      _messages.add(_LiteMessage(text: text, fromUser: true));
      _sending = true;
    });
    _scrollToEnd();

    try {
      final response = await widget.api.chat(message: text);
      if (!mounted) return;
      setState(() {
        _messages.add(_LiteMessage(text: response, fromUser: false));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _LiteMessage(
            text: error.toString().replaceFirst('Exception: ', ''),
            fromUser: false,
            isError: true,
          ),
        );
      });
    } finally {
      if (!mounted) return;
      setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A0F),
      appBar: AppBar(
        title: const Text(
          'J.A.R.V.I.S. Lite',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF070D13),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: _sending ? null : widget.onLogout,
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return Align(
                    alignment: message.fromUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 760),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: message.fromUser
                            ? Colors.blueAccent.withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: message.isError
                              ? Colors.redAccent.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: message.isError
                              ? Colors.redAccent.shade100
                              : Colors.white,
                          height: 1.35,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_sending)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: Colors.cyanAccent,
                  backgroundColor: Colors.transparent,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_sending,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Digite uma mensagem...',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                    color: Colors.black,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      disabledBackgroundColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiteMessage {
  const _LiteMessage({
    required this.text,
    required this.fromUser,
    this.isError = false,
  });

  final String text;
  final bool fromUser;
  final bool isError;
}
