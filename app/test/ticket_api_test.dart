import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:appi/api.dart';
import 'package:appi/tickets.dart';

void main() {
  late HttpServer server;
  late LocalApi api;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    api = LocalApi(baseUrl: 'http://127.0.0.1:${server.port}/api/v1');
    api.orgToken = 'local-test-token';
  });
  tearDown(() async {
    api.close();
    await server.close(force: true);
  });

  Map<String, dynamic> responseFor(Map<String, dynamic> body) => {
    'id': 'ABI-SAVED-REFERENCE', 'event_id': body['event_id'], 'name': body['name'],
    'quantity': body['quantity'], 'price_cents': 4500,
    'total_cents': (body['quantity'] as int) * 4500,
    'status': 'reserved', 'expires_at': '2027-06-01T18:00:00Z',
  };

  test('Loads live price, configured deadline and current stock', () async {
    server.listen((request) async {
      final Object body = switch (request.uri.path) {
        '/api/v1/config' => {'reservation_days': 7},
        '/api/v1/events' => [{'id': 'abi-ball', 'title': 'Testball', 'price_cents': 4700}],
        '/api/v1/events/abi-ball/availability' => {'available': 20, 'reserved': 10, 'paid': 70, 'capacity': 100},
        _ => {},
      };
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(body));
      await request.response.close();
    });
    final sale = await api.loadTicketSale();
    expect(sale.priceCents, 4700);
    expect(sale.reservationDays, 7);
    expect(sale.stock.available, 20);
  });

  test('POST sends only buyer input and UUID; retries keep identity and token stays out of body', () async {
    final bodies = <Map<String, dynamic>>[];
    final methods = <String>[];
    final auth = <String?>[];
    server.listen((request) async {
      methods.add(request.method);
      auth.add(request.headers.value(HttpHeaders.authorizationHeader));
      final body = jsonDecode(await request.cast<List<int>>().transform(utf8.decoder).join()) as Map<String, dynamic>;
      bodies.add(body);
      if (bodies.length == 1) {
        // Simulate a server failure after the write may already have committed.
        request.response.statusCode = 500;
        request.response.write(jsonEncode({'error': {'code': 'internal_error', 'message': 'Unklar'}}));
      } else {
        request.response.write(jsonEncode(responseFor(body)));
      }
      await request.response.close();
    });
    final session = TicketSession(api);
    addTearDown(session.dispose);
    await session.submit(eventId: 'abi-ball', name: 'Lina', quantity: 2);
    expect(session.pending, isNotNull);
    expect(session.reservation, isNull);
    await session.submit(eventId: 'abi-ball', name: 'Changed', quantity: 4);
    expect(bodies, hasLength(2));
    expect(bodies.first, bodies.last);
    expect(bodies.first.keys.toSet(), {'request_id', 'event_id', 'name', 'quantity'});
    expect(methods, ['POST', 'POST']);
    expect(auth, everyElement('Bearer local-test-token'));
    expect(session.reservation!.totalCents, 9000);
  });

  test('Structured capacity rejection preserves useful error code', () async {
    server.listen((request) async {
      await request.drain<void>();
      request.response.statusCode = 409;
      request.response.write(jsonEncode({'error': {
        'code': 'insufficient_capacity', 'message': 'Nicht genügend Karten verfügbar.',
      }}));
      await request.response.close();
    });
    await expectLater(api.reserveTickets(const ReservationRequest(
      requestId: 'f509a8bc-58c1-43bc-80a0-92bd356df23e', eventId: 'abi-ball', name: 'Lina', quantity: 2)),
      throwsA(isA<TicketFailure>()
        .having((error) => error.code, 'code', 'insufficient_capacity')
        .having((error) => error.outcomeUnknown, 'outcomeUnknown', false)));
  });

  test('Malformed success is an unclear write, never a booking confirmation', () async {
    server.listen((request) async {
      await request.drain<void>();
      request.response.write('{"id":"incomplete"}');
      await request.response.close();
    });
    await expectLater(api.reserveTickets(const ReservationRequest(
      requestId: 'f509a8bc-58c1-43bc-80a0-92bd356df23e', eventId: 'abi-ball', name: 'Lina', quantity: 2)),
      throwsA(isA<TicketFailure>().having((error) => error.outcomeUnknown, 'outcomeUnknown', true)));
  });
}
