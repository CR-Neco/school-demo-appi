import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'config.dart';
import 'fundraising.dart';
import 'tickets.dart';

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
class LocalApi implements AppiApi, TicketApi {
  LocalApi({String baseUrl = AppConfig.apiBaseUrl}) : _baseUrl = baseUrl;
  final String _baseUrl;
  @override
  String orgToken = const String.fromEnvironment('APPI_ORG_TOKEN');
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

  @override
  Future<TicketSale> loadTicketSale() async {
    final config = _object(await _request('GET', 'config'));
    final events = await _request('GET', 'events');
    if (events is! List) throw const TicketFailure('Veranstaltungen sind unvollständig.');
    final matches = events.whereType<Map<String, dynamic>>().where((event) => event['id'] == 'abi-ball');
    if (matches.isEmpty) throw const TicketFailure('Der Demo-Abiball ist noch nicht eingerichtet.');
    final event = matches.first;
    final price = event['price_cents'];
    final days = config['reservation_days'];
    final title = event['title'];
    if (price is! int || price < 0 || days is! int || days < 1 || title is! String) {
      throw const TicketFailure('Die Veranstaltungsdaten sind unvollständig.');
    }
    return TicketSale(eventId: 'abi-ball', title: title, priceCents: price,
      reservationDays: days, stock: await loadTicketStock('abi-ball'));
  }

  @override
  Future<TicketStock> loadTicketStock(String eventId) async {
    try {
      return TicketStock.fromJson(_object(await _request('GET', 'events/${Uri.encodeComponent(eventId)}/availability')));
    } on FormatException {
      throw const TicketFailure('Die Verfügbarkeit konnte nicht gelesen werden.');
    }
  }

  @override
  Future<Reservation> reserveTickets(ReservationRequest request) async {
    if (orgToken.trim().isEmpty) throw const TicketFailure('Bitte zuerst den lokalen Demo-Zugang eingeben.');
    final result = await _request('POST', 'reservations', body: request.toJson());
    try {
      return Reservation.fromJson(_object(result));
    } catch (_) {
      throw const TicketFailure('Die Bestätigung ist unvollständig. Bitte dieselbe Anfrage erneut senden.', outcomeUnknown: true);
    }
  }

  @override
  Future<Uint8List> loadReceipt(String reference) async {
    if (orgToken.trim().isEmpty) throw const TicketFailure('Bitte den lokalen Demo-Zugang erneut eingeben.');
    return await _request('GET', 'reservations/${Uri.encodeComponent(reference)}/receipt.pdf', pdf: true) as Uint8List;
  }

  @override
  Future<List<Reservation>> loadReservations() async {
    try {
      final value = await _request('GET', 'reservations', authenticated: true);
      if (value is! List) throw const FormatException('Liste erwartet');
      return value.map((item) => Reservation.fromJson(_object(item))).toList();
    } on FormatException {
      throw const TicketFailure('Die Reservierungsliste ist unvollständig.');
    }
  }

  @override
  Future<Reservation> loadReservation(String reference) async {
    try {
      return Reservation.fromJson(_object(await _request('GET', 'reservations/${Uri.encodeComponent(reference)}', authenticated: true)));
    } on FormatException {
      throw const TicketFailure('Die Reservierungsdaten sind unvollständig.');
    }
  }

  Future<Reservation> _changeReservation(String reference, String action, {Map<String, dynamic>? body}) async {
    final result = await _request('POST', 'reservations/${Uri.encodeComponent(reference)}/$action', body: body);
    try {
      return Reservation.fromJson(_object(result));
    } catch (_) {
      throw const TicketFailure('Die Bestätigung ist unvollständig. Bitte dieselbe Änderung erneut senden.', outcomeUnknown: true);
    }
  }

  @override
  Future<Reservation> confirmPayment(String reference) => _changeReservation(reference, 'payment');
  @override
  Future<Reservation> cancelReservation(String reference) => _changeReservation(reference, 'cancel');
  @override
  Future<Reservation> extendReservation(String reference, {required int days, required String requestId}) =>
      _changeReservation(reference, 'extend', body: {'days': days, 'request_id': requestId});

  Map<String, dynamic> _object(dynamic value) {
    if (value is! Map<String, dynamic>) throw const FormatException('JSON-Objekt erwartet');
    return value;
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    try {
      return _object(await _request('GET', path));
    } on TicketFailure catch (error) {
      throw ApiFailure(error.message);
    } on FormatException {
      throw const ApiFailure('Das Backend hat ein ungültiges Datenformat geliefert.');
    }
  }

  Future<dynamic> _request(String method, String path, {Map<String, dynamic>? body, bool pdf = false, bool authenticated = false}) async {
    HttpClientRequest? activeRequest;
    bool timedOut = false;
    final writing = method == 'POST';
    Future<dynamic> send() async {
      final base = _baseUrl.replaceFirst(RegExp(r'/+$'), '');
      final request = await _client.openUrl(method, Uri.parse('$base/$path'));
      activeRequest = request;
      if (timedOut) {
        request.abort();
        throw TimeoutException('Verbindung zu spät geöffnet');
      }
      if (writing || pdf || authenticated) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${orgToken.trim()}');
      }
      if (pdf) request.headers.set(HttpHeaders.acceptHeader, 'application/pdf');
      if (writing) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final buffer = BytesBuilder(copy: false);
      await for (final chunk in response) {
        if (buffer.length + chunk.length > 4 * 1024 * 1024) {
          request.abort();
          throw TicketFailure('Die Backend-Antwort ist unerwartet groß.', outcomeUnknown: writing);
        }
        buffer.add(chunk);
      }
      final bytes = buffer.takeBytes();
      if (response.statusCode >= 200 && response.statusCode < 300 && pdf) {
        final signature = bytes.length >= 5 ? ascii.decode(bytes.sublist(0, 5), allowInvalid: true) : '';
        if (response.headers.contentType?.mimeType != 'application/pdf' || signature != '%PDF-') {
          throw const TicketFailure('Das Backend hat keinen gültigen PDF-Beleg geliefert.');
        }
        return bytes;
      }
      final text = utf8.decode(bytes);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String? code;
        String message = 'Das Backend meldet einen Fehler. Bitte erneut versuchen.';
        try {
          final error = _object(_object(jsonDecode(text))['error']);
          code = error['code'] as String?;
          message = error['message'] as String? ?? message;
        } catch (_) { /* A non-JSON failure must not hide its HTTP status. */ }
        // Only explicit client errors establish that this request was rejected.
        final rejected = {401, 403, 404, 409, 422}.contains(response.statusCode);
        throw TicketFailure(message, code: code, outcomeUnknown: writing && !rejected);
      }
      return jsonDecode(text);
    }
    try {
      return await send().timeout(const Duration(seconds: 6));
    } on TicketFailure {
      rethrow;
    } on TimeoutException {
      timedOut = true;
      activeRequest?.abort();
      throw TicketFailure('Das Backend antwortet gerade nicht. Bitte erneut versuchen.', outcomeUnknown: writing);
    } on SocketException {
      throw TicketFailure('Starte das AppI-Backend auf deinem Mac und versuche es erneut.', outcomeUnknown: writing);
    } on Exception {
      throw TicketFailure('Die Backend-Antwort konnte nicht gelesen werden. Bitte erneut versuchen.', outcomeUnknown: writing);
    }
  }

  @override
  void close() => _client.close(force: true);
}
