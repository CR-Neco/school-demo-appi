import 'dart:math';

import 'package:flutter/foundation.dart';

class TicketFailure implements Exception {
  const TicketFailure(this.message, {this.code, this.outcomeUnknown = false});
  final String message;
  final String? code;
  final bool outcomeUnknown;
}

abstract interface class TicketApi {
  String get orgToken;
  set orgToken(String value);
  Future<TicketSale> loadTicketSale();
  Future<TicketStock> loadTicketStock(String eventId);
  Future<Reservation> reserveTickets(ReservationRequest request);
  Future<Uint8List> loadReceipt(String reference);
  Future<List<Reservation>> loadReservations();
  Future<Reservation> loadReservation(String reference);
  Future<Reservation> confirmPayment(String reference);
  Future<Reservation> cancelReservation(String reference);
  Future<Reservation> extendReservation(String reference, {required int days, required String requestId});
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) throw const FormatException('Ungültige Zahl');
  return value;
}

String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Fehlender Text');
  }
  return value;
}

class TicketStock {
  const TicketStock({required this.available, required this.reserved,
    required this.paid, required this.capacity});
  factory TicketStock.fromJson(Map<String, dynamic> json) => TicketStock(
    available: _integer(json, 'available'), reserved: _integer(json, 'reserved'),
    paid: _integer(json, 'paid'), capacity: _integer(json, 'capacity'));
  final int available, reserved, paid, capacity;
}

class TicketSale {
  const TicketSale({required this.eventId, required this.title,
    required this.priceCents, required this.reservationDays, required this.stock});
  final String eventId, title;
  final int priceCents, reservationDays;
  final TicketStock stock;
}

class ReservationRequest {
  const ReservationRequest({required this.requestId, required this.eventId,
    required this.name, required this.quantity});
  final String requestId, eventId, name;
  final int quantity;
  Map<String, dynamic> toJson() => {'request_id': requestId, 'event_id': eventId,
    'name': name, 'quantity': quantity};
}

class Reservation {
  const Reservation({required this.reference, required this.eventId,
    required this.name, required this.quantity, required this.priceCents,
    required this.totalCents, required this.status, required this.expiresAt, this.overdue = false});
  factory Reservation.fromJson(Map<String, dynamic> json) {
    final status = _text(json, 'status');
    if (!{'reserved', 'paid', 'cancelled'}.contains(status)) {
      throw const FormatException('Ungültiger Status');
    }
    final quantity = _integer(json, 'quantity');
    final price = _integer(json, 'price_cents');
    final total = _integer(json, 'total_cents');
    if (quantity < 1 || total != quantity * price) {
      throw const FormatException('Ungültiger Betrag');
    }
    if (json['overdue'] != null && json['overdue'] is! bool) throw const FormatException('Ungültige Fristinformation');
    return Reservation(reference: _text(json, 'id'), eventId: _text(json, 'event_id'),
      name: _text(json, 'name'), quantity: quantity, priceCents: price,
      totalCents: total, status: status, expiresAt: DateTime.parse(_text(json, 'expires_at')), overdue: json['overdue'] == true);
  }
  final String reference, eventId, name, status;
  final int quantity, priceCents, totalCents;
  final DateTime expiresAt;
  final bool overdue;
  bool get isOpen => status == 'reserved';
  String get statusLabel => switch (status) {
    'paid' => 'Bezahlt', 'cancelled' => 'Storniert',
    _ => overdue ? 'Überfällig · weiter reserviert' : 'Reserviert · noch nicht bezahlt',
  };
}

String? validateBuyerName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Bitte einen Namen eingeben.';
  if (name.runes.length > 120) return 'Der Name darf höchstens 120 Zeichen haben.';
  return null;
}

String? validateTicketQuantity(String? value) {
  final quantity = int.tryParse(value?.trim() ?? '');
  if (quantity == null || quantity < 1 || quantity > 1000) {
    return 'Bitte eine ganze Anzahl von 1 bis 1000 eingeben.';
  }
  return null;
}

String newReservationRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Owned by the app, so returning to the dashboard cannot lose an unclear request.
/// Pending payloads stay frozen until the server confirms or rejects them.
class TicketSession extends ChangeNotifier {
  TicketSession(this.api);
  final TicketApi api;
  ReservationRequest? pending;
  Reservation? reservation;
  String? error;
  bool submitting = false;
  bool _disposed = false;
  bool _unclear = false;

  Future<void> submit({required String eventId, required String name, required int quantity}) async {
    if (submitting || reservation != null) return;
    pending ??= ReservationRequest(requestId: newReservationRequestId(),
      eventId: eventId, name: name.trim(), quantity: quantity);
    submitting = true;
    error = null;
    notifyListeners();
    try {
      reservation = await api.reserveTickets(pending!);
      pending = null;
      _unclear = false;
    } catch (failure) {
      // An unexpected client/parse error after a POST is also an unclear outcome.
      if (failure is TicketFailure) {
        error = failure.message;
        _unclear = _unclear || failure.outcomeUnknown;
        if (!_unclear) pending = null;
      } else {
        _unclear = true;
        error = 'Antwort unklar. Bitte dieselbe Anfrage erneut senden.';
      }
    } finally {
      submitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  void updateReservation(Reservation value) {
    if (_disposed || reservation?.reference != value.reference) return;
    reservation = value;
    notifyListeners();
  }

  void newOrder() {
    if (submitting || pending != null) return;
    reservation = null;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

String reservationDeadline(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}, ${two(local.hour)}:${two(local.minute)} Uhr';
}
