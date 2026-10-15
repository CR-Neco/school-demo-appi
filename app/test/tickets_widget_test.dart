import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appi/screens/tickets.dart';
import 'package:appi/tickets.dart';
import 'package:appi/api.dart';
import 'package:appi/fundraising.dart';
import 'package:appi/main.dart';

import 'support/ticket_fake.dart';

Future<void> show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 180,
    scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester, TicketSession session) async {
  await tester.pumpWidget(MaterialApp(home: TicketsScreen(session: session, year: 2028)));
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester) async {
  await show(tester, find.byKey(const Key('buyer-name')));
  await tester.enterText(find.byKey(const Key('buyer-name')), 'Lina Beispiel');
  await tester.enterText(find.byKey(const Key('ticket-quantity')), '2');
  await tester.pump();
}

class FullDemoApi extends FakeTicketApi implements AppiApi {
  @override
  Future<SchoolConfig> loadConfig() async => const SchoolConfig(school: 'Demo Schule', year: 2028);
  @override
  Future<Fundraising> loadDashboard() async => const Fundraising(targetCents: 1500000, raisedCents: 0);
  @override
  void close() {}
}

void main() {
  testWidgets('Dashboard ticket card opens the live reservation screen', (tester) async {
    await tester.pumpWidget(AppiApp(api: FullDemoApi()));
    await tester.pumpAndSettle();
    await show(tester, find.text('Abiball-Tickets'));
    await tester.tap(find.text('Abiball-Tickets'));
    await tester.pumpAndSettle();
    expect(find.text('Euer Abiball 2028'), findsOneWidget);
    expect(find.text('300 verfügbar · 0 reserviert · 0 bezahlt'), findsOneWidget);
  });

  testWidgets('Validation prevents invalid requests; total follows quantity', (tester) async {
    final api = FakeTicketApi();
    final session = TicketSession(api);
    addTearDown(session.dispose);
    await open(tester, session);
    await fill(tester);
    expect(find.text('Gesamt: 90,00 €'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('buyer-name')), '  ');
    await tester.enterText(find.byKey(const Key('ticket-quantity')), '0');
    await show(tester, find.byKey(const Key('reserve-tickets')));
    await tester.tap(find.byKey(const Key('reserve-tickets')));
    await tester.pumpAndSettle();
    expect(api.requests, isEmpty);
    await show(tester, find.text('Bitte einen Namen eingeben.'));
    expect(find.text('Bitte einen Namen eingeben.'), findsOneWidget);
  });

  testWidgets('Success shows saved reference and reloads availability', (tester) async {
    final api = FakeTicketApi();
    final session = TicketSession(api);
    addTearDown(session.dispose);
    await open(tester, session);
    await fill(tester);
    await show(tester, find.byKey(const Key('reserve-tickets')));
    await tester.tap(find.byKey(const Key('reserve-tickets')));
    await tester.pumpAndSettle();
    await show(tester, find.text('Reservierung gespeichert'));
    expect(find.text('Reservierung gespeichert'), findsOneWidget);
    expect(find.text('ABI-DEMO-123'), findsOneWidget);
    expect(find.text('2 Karten · 90,00 €'), findsOneWidget);
    expect(api.stockCalls, 1);
    await show(tester, find.text('Reservierungsdaten öffnen'));
    await tester.tap(find.text('Reservierungsdaten öffnen'));
    await tester.pumpAndSettle();
    expect(find.text('Reservierungsübersicht'), findsOneWidget);
    expect(find.text('Referenz: ABI-DEMO-123'), findsOneWidget);
  });

  testWidgets('Capacity conflict preserves inputs and allows correcting quantity', (tester) async {
    final api = FakeTicketApi();
    api.handler = (_) async => throw const TicketFailure('Nicht genügend Karten verfügbar.', code: 'insufficient_capacity');
    final session = TicketSession(api);
    addTearDown(session.dispose);
    await open(tester, session);
    await fill(tester);
    await show(tester, find.byKey(const Key('reserve-tickets')));
    await tester.tap(find.byKey(const Key('reserve-tickets')));
    await tester.pumpAndSettle();
    await show(tester, find.text('Nicht genügend Karten verfügbar.'));
    expect(find.text('Nicht genügend Karten verfügbar.'), findsOneWidget);
    await show(tester, find.byKey(const Key('buyer-name')));
    expect(tester.widget<TextFormField>(find.byKey(const Key('buyer-name'))).controller!.text, 'Lina Beispiel');
    final count = tester.widget<TextFormField>(find.byKey(const Key('ticket-quantity')));
    expect(count.controller!.text, '2');
    expect(tester.widget<TextField>(find.descendant(
      of: find.byKey(const Key('ticket-quantity')),
      matching: find.byType(TextField))).readOnly, isFalse);
    expect(find.text('Reservierung gespeichert'), findsNothing);
  });

  testWidgets('Unclear response locks inputs and retries the same request after reopening', (tester) async {
    final api = FakeTicketApi();
    api.handler = (_) async => throw const TicketFailure('Antwort unklar', outcomeUnknown: true);
    final session = TicketSession(api);
    addTearDown(session.dispose);
    await open(tester, session);
    await fill(tester);
    await show(tester, find.byKey(const Key('reserve-tickets')));
    await tester.tap(find.byKey(const Key('reserve-tickets')));
    await tester.pumpAndSettle();
    final id = api.requests.single.requestId;
    // Recreate the route while keeping the app-owned session.
    await tester.pumpWidget(const SizedBox());
    await open(tester, session);
    await show(tester, find.byKey(const Key('buyer-name')));
    expect(tester.widget<TextField>(find.descendant(
      of: find.byKey(const Key('buyer-name')),
      matching: find.byType(TextField))).readOnly, isTrue);
    api.handler = (request) async => confirmed(request);
    await show(tester, find.text('Dieselbe Anfrage erneut senden'));
    await tester.tap(find.text('Dieselbe Anfrage erneut senden'));
    await tester.pumpAndSettle();
    expect(api.requests, hasLength(2));
    expect(api.requests.last.requestId, id);
    expect(session.reservation, isNotNull);
  });

  testWidgets('Submit stays disabled until backend confirms', (tester) async {
    final api = FakeTicketApi();
    final pending = Completer<Reservation>();
    api.handler = (_) => pending.future;
    final session = TicketSession(api);
    addTearDown(session.dispose);
    await open(tester, session);
    await fill(tester);
    await show(tester, find.byKey(const Key('reserve-tickets')));
    await tester.tap(find.byKey(const Key('reserve-tickets')));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('reserve-tickets'))).onPressed, isNull);
    expect(find.text('Reservierung gespeichert'), findsNothing);
    pending.complete(confirmed(api.requests.single));
    await tester.pumpAndSettle();
    expect(session.reservation, isNotNull);
  });
}
