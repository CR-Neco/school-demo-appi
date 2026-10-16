import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'config.dart';
import 'fundraising.dart';

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
  Future<Fundraising> loadDashboard();
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
    final json = await _getJson('config');
    if (json['school'] is! String || json['year'] is! int) {
      throw const ApiFailure('Die Schulkonfiguration ist ungültig.');
    }
    return SchoolConfig(school: json['school'] as String, year: json['year'] as int);
  }

  @override
  Future<Fundraising> loadDashboard() async {
    final json = await _getJson('dashboard');
    try {
      return Fundraising.fromJson(json);
    } on FormatException {
      throw const ApiFailure('Die Finanzierungsdaten sind unvollständig. Bitte erneut versuchen.');
    }
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    try {
      return await _fetchJson(path).timeout(const Duration(seconds: 6));
    } on ApiFailure {
      rethrow;
    } on TimeoutException {
      throw const ApiFailure('Das Backend antwortet gerade nicht. Bitte erneut versuchen.');
    } on SocketException {
      throw const ApiFailure('Starte das AppI-Backend auf deinem Mac und versuche es erneut.');
    } on Exception {
      throw const ApiFailure('Die Backend-Antwort konnte nicht geladen werden. Bitte erneut versuchen.');
    }
  }

  Future<Map<String, dynamic>> _fetchJson(String path) async {
    final base = _baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final request = await _client.getUrl(Uri.parse('$base/$path'));
    final response = await request.close();
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw const ApiFailure('Das Backend meldet einen Fehler. Bitte erneut versuchen.');
    }
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      throw const ApiFailure('Das Backend hat ein ungültiges Datenformat geliefert.');
    }
    return json;
  }

  @override
  void close() => _client.close(force: true);
}
