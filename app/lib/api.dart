import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'config.dart';

class SchoolConfig {
  const SchoolConfig({required this.school, required this.year});
  final String school;
  final int year;
}

class ApiFailure implements Exception {
  const ApiFailure(this.message);
  final String message;
}

abstract interface class AppiApi {
  Future<SchoolConfig> loadConfig();
  void close();
}

/// Local iOS-simulator transport. No third-party networking dependency needed.
class LocalApi implements AppiApi {
  LocalApi({String baseUrl = AppConfig.apiBaseUrl}) : _baseUrl = baseUrl;
  final String _baseUrl;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4);

  @override
  Future<SchoolConfig> loadConfig() async {
    try {
      return await _fetchConfig().timeout(const Duration(seconds: 6));
    } on ApiFailure {
      rethrow;
    } on TimeoutException {
      throw const ApiFailure(
        'Das Backend antwortet gerade nicht. Bitte Verbindung erneut versuchen.',
      );
    } on SocketException {
      throw const ApiFailure(
        'Starte das AppI-Backend auf deinem Mac und versuche es erneut.',
      );
    } on Exception {
      throw const ApiFailure(
        'Die Backend-Antwort konnte nicht geladen werden. Bitte erneut versuchen.',
      );
    }
  }

  Future<SchoolConfig> _fetchConfig() async {
    final base = _baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final request = await _client.getUrl(Uri.parse('$base/config'));
    final response = await request.close();
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw const ApiFailure(
        'Das Backend meldet einen Fehler. Bitte erneut versuchen.',
      );
    }
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    return SchoolConfig(
      school: json['school'] as String,
      year: json['year'] as int,
    );
  }

  @override
  void close() => _client.close(force: true);
}
