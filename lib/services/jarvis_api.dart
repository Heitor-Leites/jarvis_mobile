import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


class JarvisApi {
  JarvisApi({
    required this.baseUrl,
  });

  final String baseUrl;


  Future<SharedPreferences> _preferences() async {
    return SharedPreferences.getInstance();
  }


  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/login'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'username': username.trim(),
            'password': password,
          }),
        )
        .timeout(
          const Duration(seconds: 30),
        );

    final data = _decodeResponse(response);

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Usuário ou senha inválidos.',
      );
    }

    final token = data['access_token'];

    if (token == null ||
        token.toString().isEmpty) {
      throw Exception(
        'SERVER_ERROR: Token não recebido.',
      );
    }

    final prefs = await _preferences();

    await prefs.setString(
      'jarvis_token',
      token.toString(),
    );

    if (data['username'] != null) {
      await prefs.setString(
        'jarvis_username',
        data['username'].toString(),
      );
    }

    if (data['user_id'] != null) {
      await prefs.setInt(
        'jarvis_user_id',
        data['user_id'] as int,
      );
    }

    return data;
  }


  Future<bool> isLoggedIn() async {
    final prefs = await _preferences();

    final token = prefs.getString(
      'jarvis_token',
    );

    if (token == null ||
        token.trim().isEmpty) {
      return false;
    }

    try {
      await getMe();
      return true;
    } catch (error) {
      debugPrint(
        'Sessão inválida: $error',
      );

      await logout();
      return false;
    }
  }


  Future<Map<String, dynamic>> getMe() async {
    final response = await _authorizedGet(
      '/me',
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 401) {
      await logout();

      throw Exception(
        'SESSION_EXPIRED',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Não foi possível obter o usuário.',
      );
    }

    return data;
  }


  Future<String> chat({
    required String message,
  }) async {
    final response = await _authorizedPost(
      '/chat',
      {
        'message': message,
      },
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 401) {
      await logout();

      throw Exception(
        'SESSION_EXPIRED',
      );
    }

    if (response.statusCode == 422) {
      throw Exception(
        'VALIDATION_ERROR',
      );
    }

    if (response.statusCode == 503) {
      throw Exception(
        'SERVICE_UNAVAILABLE',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'SERVER_ERROR',
      );
    }

    final answer =
        data['response']?.toString();

    if (answer == null ||
        answer.trim().isEmpty) {
      throw Exception(
        'SERVER_ERROR',
      );
    }

    return answer;
  }


  Future<List<dynamic>> getConversations() async {
    final response = await _authorizedGet(
      '/conversations',
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 401) {
      await logout();

      throw Exception(
        'SESSION_EXPIRED',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Não foi possível carregar as conversas.',
      );
    }

    if (data is List) {
      return data;
    }

    return [];
  }


  Future<void> deleteConversation(
    int conversationId,
  ) async {
    final response = await _authorizedDelete(
      '/conversations/$conversationId',
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 401) {
      await logout();

      throw Exception(
        'SESSION_EXPIRED',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Não foi possível excluir a conversa.',
      );
    }
  }


  Future<List<dynamic>> getMemories() async {
    final response = await _authorizedGet(
      '/memories',
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 401) {
      await logout();

      throw Exception(
        'SESSION_EXPIRED',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Não foi possível carregar as memórias.',
      );
    }

    if (data is List) {
      return data;
    }

    return [];
  }


  Future<Map<String, dynamic>> createMemory({
    required String content,
    String category = 'general',
    int importance = 3,
  }) async {
    final response = await _authorizedPost(
      '/memories',
      {
        'content': content,
        'category': category,
        'importance': importance,
      },
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 401) {
      await logout();

      throw Exception(
        'SESSION_EXPIRED',
      );
    }

    if (response.statusCode == 422) {
      throw Exception(
        'VALIDATION_ERROR',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Não foi possível criar a memória.',
      );
    }

    return data;
  }


  Future<Map<String, dynamic>> detectMemory({
    required String content,
  }) async {
    final response = await _authorizedPost(
      '/memories/detect',
      {
        'content': content,
      },
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 401) {
      await logout();

      throw Exception(
        'SESSION_EXPIRED',
      );
    }

    if (response.statusCode == 422) {
      throw Exception(
        'VALIDATION_ERROR',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Não foi possível detectar a memória.',
      );
    }

    return data;
  }


  Future<void> deleteMemory(
    int memoryId,
  ) async {
    final response = await _authorizedDelete(
      '/memories/$memoryId',
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 401) {
      await logout();

      throw Exception(
        'SESSION_EXPIRED',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Não foi possível excluir a memória.',
      );
    }
  }


  Future<void> logout() async {
    final prefs = await _preferences();

    await prefs.remove(
      'jarvis_token',
    );

    await prefs.remove(
      'jarvis_username',
    );

    await prefs.remove(
      'jarvis_user_id',
    );
  }


  Future<String?> getToken() async {
    final prefs = await _preferences();

    return prefs.getString(
      'jarvis_token',
    );
  }


  Future<http.Response> _authorizedGet(
    String path,
  ) async {
    final token = await getToken();

    if (token == null ||
        token.trim().isEmpty) {
      throw Exception(
        'NOT_AUTHENTICATED',
      );
    }

    return http
        .get(
          Uri.parse('$baseUrl$path'),
          headers: {
            'Authorization':
                'Bearer $token',
            'Content-Type':
                'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 50),
        );
  }


  Future<http.Response> _authorizedPost(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await getToken();

    if (token == null ||
        token.trim().isEmpty) {
      throw Exception(
        'NOT_AUTHENTICATED',
      );
    }

    return http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {
            'Authorization':
                'Bearer $token',
            'Content-Type':
                'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(
          const Duration(seconds: 60),
        );
  }


  Future<http.Response> _authorizedDelete(
    String path,
  ) async {
    final token = await getToken();

    if (token == null ||
        token.trim().isEmpty) {
      throw Exception(
        'NOT_AUTHENTICATED',
      );
    }

    return http
        .delete(
          Uri.parse('$baseUrl$path'),
          headers: {
            'Authorization':
                'Bearer $token',
            'Content-Type':
                'application/json',
          },
        )
        .timeout(
          const Duration(seconds: 30),
        );
  }


  dynamic _decodeResponse(
    http.Response response,
  ) {
    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(
        response.body,
      );
    } catch (error) {
      debugPrint(
        'Erro ao decodificar resposta: $error',
      );

      return <String, dynamic>{
        'detail':
            'Resposta inválida do servidor.',
      };
    }
  }
}