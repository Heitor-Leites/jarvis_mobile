
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class JarvisApi {
  JarvisApi({
    required this.baseUrl,
  });

  final String baseUrl;

  static const String _tokenKey = 'jarvis_access_token';
  static const String _usernameKey = 'jarvis_username';
  static const String _userIdKey = 'jarvis_user_id';

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
            'username': username,
            'password': password,
          }),
        )
        .timeout(
          const Duration(seconds: 15),
        );

    final dynamic data = _decodeResponse(response);

    if (response.statusCode != 200) {
      throw Exception(
        data is Map<String, dynamic>
            ? data['detail']?.toString() ??
                'Não foi possível realizar o login.'
            : 'Não foi possível realizar o login.',
      );
    }

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'Resposta inválida recebida no login.',
      );
    }

    final String? accessToken =
        data['access_token']?.toString();

    final String? loggedUsername =
        data['username']?.toString();

    final int? userId =
        data['user_id'] is int
            ? data['user_id'] as int
            : int.tryParse(
                data['user_id']?.toString() ?? '',
              );

    if (accessToken == null ||
        accessToken.isEmpty) {
      throw Exception(
        'O servidor não retornou um token de acesso.',
      );
    }

    final prefs = await _preferences();

    await prefs.setString(
      _tokenKey,
      accessToken,
    );

    if (loggedUsername != null) {
      await prefs.setString(
        _usernameKey,
        loggedUsername,
      );
    }

    if (userId != null) {
      await prefs.setInt(
        _userIdKey,
        userId,
      );
    }

    return {
      'access_token': accessToken,
      'token_type': data['token_type']?.toString() ?? 'bearer',
      'user_id': userId,
      'username': loggedUsername,
    };
  }

  Future<void> logout() async {
    final prefs = await _preferences();

    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_userIdKey);
  }

  Future<String?> getToken() async {
    final prefs = await _preferences();

    return prefs.getString(_tokenKey);
  }

  Future<String?> getUsername() async {
    final prefs = await _preferences();

    return prefs.getString(_usernameKey);
  }

  Future<int?> getUserId() async {
    final prefs = await _preferences();

    return prefs.getInt(_userIdKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();

    return token != null && token.isNotEmpty;
  }

  Future<String> chat({
    required String message,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'NOT_AUTHENTICATED',
      );
    }

    final response = await http
        .post(
          Uri.parse('$baseUrl/chat'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'message': message,
          }),
        )
        .timeout(
          const Duration(seconds: 45),
        );

    if (response.statusCode == 200) {
      final dynamic data = _decodeResponse(response);

      if (data is Map<String, dynamic>) {
        return data['response']?.toString() ??
            'Não consegui gerar uma resposta.';
      }

      throw Exception(
        'Resposta inválida recebida do servidor.',
      );
    }

    if (response.statusCode == 401) {
      await logout();

      throw Exception(
        'SESSION_EXPIRED',
      );
    }

    if (response.statusCode == 503) {
      throw Exception(
        'SERVICE_UNAVAILABLE',
      );
    }

    if (response.statusCode == 422) {
      throw Exception(
        'VALIDATION_ERROR',
      );
    }

    if (response.statusCode >= 500) {
      throw Exception(
        'SERVER_ERROR',
      );
    }

    throw Exception(
      'HTTP_${response.statusCode}',
    );
  }

  Future<List<Map<String, dynamic>>> getMemories() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'NOT_AUTHENTICATED',
      );
    }

    final response = await http
        .get(
          Uri.parse('$baseUrl/memory'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(
          const Duration(seconds: 15),
        );

    if (response.statusCode == 200) {
      final dynamic data = _decodeResponse(response);

      if (data is! List) {
        throw Exception(
          'Resposta de memórias inválida.',
        );
      }

      return data
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    if (response.statusCode == 401) {
      await logout();

      throw Exception(
        'SESSION_EXPIRED',
      );
    }

    throw Exception(
      'HTTP_${response.statusCode}',
    );
  }

  Future<Map<String, dynamic>> createMemory({
    required String content,
    String category = 'general',
    int importance = 1,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'NOT_AUTHENTICATED',
      );
    }

    final response = await http
        .post(
          Uri.parse('$baseUrl/memory'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'content': content,
            'category': category,
            'importance': importance,
          }),
        )
        .timeout(
          const Duration(seconds: 15),
        );

    final dynamic data = _decodeResponse(response);

    if (response.statusCode == 200) {
      if (data is Map<String, dynamic>) {
        return data;
      }

      throw Exception(
        'Resposta inválida ao criar memória.',
      );
    }

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

    throw Exception(
      'HTTP_${response.statusCode}',
    );
  }

  Future<void> deleteMemory(
    int memoryId,
  ) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'NOT_AUTHENTICATED',
      );
    }

    final response = await http
        .delete(
          Uri.parse(
            '$baseUrl/memory/$memoryId',
          ),
          headers: {
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(
          const Duration(seconds: 15),
        );

    if (response.statusCode == 200) {
      return;
    }

    if (response.statusCode == 401) {
      await logout();

      throw Exception(
        'SESSION_EXPIRED',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'MEMORY_NOT_FOUND',
      );
    }

    throw Exception(
      'HTTP_${response.statusCode}',
    );
  }

  dynamic _decodeResponse(
    http.Response response,
  ) {
    if (response.body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }
}

