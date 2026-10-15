import 'dart:typed_data';

import 'package:appi/tickets.dart';

const sale = TicketSale(eventId: 'abi-ball', title: 'Abiball (Demo)',
  priceCents: 4500, reservationDays: 5,
  stock: TicketStock(available: 300, reserved: 0, paid: 0, capacity: 300));

Reservation confirmed(ReservationRequest request) => Reservation(
  reference: 'ABI-DEMO-123', eventId: request.eventId, name: request.name,
  quantity: request.quantity, priceCents: 4500, totalCents: request.quantity * 4500,
  status: 'reserved', expiresAt: DateTime.utc(2027, 6, 1, 18));

class FakeTicketApi implements TicketApi {
  @override
  String orgToken = 'local-test-token';
  final List<ReservationRequest> requests = [];
  int stockCalls = 0;
  int receiptCalls = 0;
  Future<Uint8List> Function(String)? receiptHandler;
  Future<List<Reservation>> Function()? listLoader;
  Future<Reservation> Function(String)? detailLoader, paymentHandler, cancelHandler;
  Future<Reservation> Function(String, int, String)? extendHandler;
  final List<String> detailRequests = [], paymentRequests = [], cancelRequests = [], extensionIds = [];
  int listCalls = 0;

  @override
  Future<List<Reservation>> loadReservations() async {
    listCalls++;
    if (listLoader != null) return await listLoader!();
    return [];
  }
  @override
  Future<Reservation> loadReservation(String reference) async {
    detailRequests.add(reference);
    if (detailLoader != null) return await detailLoader!(reference);
    throw const TicketFailure('Reservierung nicht gefunden.');
  }
  @override
  Future<Reservation> confirmPayment(String reference) async {
    paymentRequests.add(reference);
    if (paymentHandler != null) return await paymentHandler!(reference);
    throw const TicketFailure('Zahlung nicht vorbereitet.');
  }
  @override
  Future<Reservation> cancelReservation(String reference) async {
    cancelRequests.add(reference);
    if (cancelHandler != null) return await cancelHandler!(reference);
    throw const TicketFailure('Storno nicht vorbereitet.');
  }
  @override
  Future<Reservation> extendReservation(String reference, {required int days, required String requestId}) async {
    extensionIds.add(requestId);
    if (extendHandler != null) return await extendHandler!(reference, days, requestId);
    throw const TicketFailure('Verlängerung nicht vorbereitet.');
  }

  Future<Reservation> Function(ReservationRequest)? handler;
  Future<TicketStock> Function()? stockHandler;
  @override
  Future<Uint8List> loadReceipt(String reference) async {
    receiptCalls++;
    if (receiptHandler != null) return await receiptHandler!(reference);
    return Uint8List.fromList('%PDF-1.4 fake'.codeUnits);
  }
  @override
  Future<TicketSale> loadTicketSale() async => sale;
  @override
  Future<TicketStock> loadTicketStock(String eventId) async {
    stockCalls++;
    if (stockHandler != null) return await stockHandler!();
    return sale.stock;
  }
  @override
  Future<Reservation> reserveTickets(ReservationRequest request) async {
    requests.add(request);
    if (handler != null) return await handler!(request);
    return confirmed(request);
  }
}

