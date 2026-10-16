import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:appi/tickets.dart';

import 'support/ticket_fake.dart';

void main() {
  test('Buyer name and whole positive quantity are validated', () {
    expect(validateBuyerName('  '), isNotNull);
    expect(validateBuyerName('A' * 121), isNotNull);
    expect(validateBuyerName('  Lina Beispiel  '), isNull);
    for (final value in ['', '0', '-1', '1.5', '1001', 'zwei']) {
      expect(validateTicketQuantity(value), isNotNull);
    }
    expect(validateTicketQuantity(' 2 '), isNull);
  });

  test('Duplicate taps submit one request and wait for backend confirmation', () async {
    final api = FakeTicketApi();
    final pending = Completer<Reservation>();
    api.handler = (_) => pending.future;
    final session = TicketSession(api);
    addTearDown(session.dispose);
    final first = session.submit(eventId: 'abi-ball', name: ' Lina ', quantity: 2);
    await session.submit(eventId: 'abi-ball', name: 'Other', quantity: 3);
    expect(api.requests, hasLength(1));
    expect(session.reservation, isNull);
    expect(api.requests.single.name, 'Lina');
    expect(api.requests.single.requestId,
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    pending.complete(confirmed(api.requests.single));
    await first;
    expect(session.reservation!.totalCents, 9000);
    expect(session.pending, isNull);
  });

  test('Lost response and later auth failure keep the same frozen request', () async {
    final api = FakeTicketApi();
    final session = TicketSession(api);
    addTearDown(session.dispose);
    api.handler = (_) async => throw const TicketFailure('Zeitüberschreitung', outcomeUnknown: true);
    await session.submit(eventId: 'abi-ball', name: 'Lina', quantity: 2);
    final original = session.pending!;
    session.newOrder();
    expect(session.pending, same(original));
    api.handler = (_) async => throw const TicketFailure('Zugang korrigieren');
    await session.submit(eventId: 'different', name: 'Changed', quantity: 99);
    expect(session.pending, same(original));
    api.handler = (request) async => confirmed(request);
    await session.submit(eventId: 'different', name: 'Changed', quantity: 99);
    expect(api.requests.map((request) => request.requestId).toSet(), {original.requestId});
    expect(api.requests.every((request) => request.name == 'Lina' && request.quantity == 2), isTrue);
    expect(session.reservation!.reference, 'ABI-DEMO-123');
  });

  test('Known capacity rejection permits a corrected new request', () async {
    final api = FakeTicketApi();
    final session = TicketSession(api);
    addTearDown(session.dispose);
    api.handler = (_) async => throw const TicketFailure('Nicht genügend Karten verfügbar.', code: 'insufficient_capacity');
    await session.submit(eventId: 'abi-ball', name: 'Lina', quantity: 2);
    expect(session.pending, isNull);
    expect(session.error, contains('Nicht genügend'));
    api.handler = (request) async => confirmed(request);
    await session.submit(eventId: 'abi-ball', name: 'Lina', quantity: 1);
    expect(api.requests[0].requestId, isNot(api.requests[1].requestId));
    expect(session.reservation!.quantity, 1);
  });

  test('Success uses saved server totals, status and deadline', () {
    final reservation = Reservation.fromJson({
      'id': 'opaque-reference', 'event_id': 'abi-ball', 'name': 'Lina',
      'quantity': 2, 'price_cents': 4700, 'total_cents': 9400,
      'status': 'reserved', 'expires_at': '2027-06-01T18:00:00Z',
    });
    expect(reservation.totalCents, 9400);
    expect(reservation.expiresAt, DateTime.utc(2027, 6, 1, 18));
    expect(reservation.statusLabel, contains('noch nicht bezahlt'));
    expect(() => Reservation.fromJson({'quantity': 2}), throwsFormatException);
  });
}
