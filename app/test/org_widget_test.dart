import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appi/api.dart';
import 'package:appi/fundraising.dart';
import 'package:appi/main.dart';
import 'package:appi/org.dart';
import 'package:appi/screens/org.dart';
import 'package:appi/tickets.dart';

import 'support/org_sample.dart';
import 'support/ticket_fake.dart';

Future<void> show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 180, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<ReservationAdmin> openDetail(WidgetTester tester, FakeTicketApi api) async {
  api.detailLoader ??= (_) async => sample();
  final admin = ReservationAdmin(api, 'ABI-ORG-123');
  addTearDown(admin.dispose);
  await tester.pumpWidget(MaterialApp(home: OrgReservationScreen(admin: admin, api: api)));
  await tester.pumpAndSettle();
  return admin;
}

class FullOrgApi extends FakeTicketApi implements AppiApi {
  bool paid = false;
  @override
  Future<SchoolConfig> loadConfig() async => const SchoolConfig(school: 'Demo Schule', year: 2027);
  @override
  Future<Fundraising> loadDashboard() async => Fundraising(targetCents: 1500000, raisedCents: paid ? 9000 : 0);
  @override
  Future<List<Reservation>> loadReservations() async => [sample(status: paid ? 'paid' : 'reserved')];
  @override
  Future<Reservation> loadReservation(String reference) async => sample(status: paid ? 'paid' : 'reserved');
  @override
  Future<Reservation> confirmPayment(String reference) async { paid = true; return sample(status: 'paid'); }
  @override
  void close() {}
}

void main() {
  testWidgets('Payment requires confirmation; cancelling sends no mutation', (tester) async {
    final api = FakeTicketApi();
    await openDetail(tester, api);
    await show(tester, find.byKey(const Key('payment-action')));
    await tester.tap(find.byKey(const Key('payment-action')));
    await tester.pumpAndSettle();
    expect(find.text('Zahlungseingang bestätigen?'), findsOneWidget);
    expect(api.paymentRequests, isEmpty);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(api.paymentRequests, isEmpty);
    expect(find.text('Reserviert · noch nicht bezahlt'), findsOneWidget);
  });

  testWidgets('No optimistic paid status while payment is pending', (tester) async {
    final api = FakeTicketApi();
    final pending = Completer<Reservation>();
    api.paymentHandler = (_) => pending.future;
    await openDetail(tester, api);
    await show(tester, find.byKey(const Key('payment-action')));
    await tester.tap(find.byKey(const Key('payment-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-org-change')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Bezahlt'), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const Key('payment-action'))).onPressed, isNull);
    pending.complete(sample(status: 'paid'));
    await tester.pumpAndSettle();
    expect(find.text('Bezahlt'), findsOneWidget);
    expect(find.byKey(const Key('payment-action')), findsNothing);
  });

  testWidgets('Extension and cancellation both require explicit confirmation', (tester) async {
    final api = FakeTicketApi();
    await openDetail(tester, api);
    for (final key in ['extend-action', 'cancel-action']) {
      await show(tester, find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirm-org-change')), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
    }
    expect(api.extensionIds, isEmpty);
    expect(api.cancelRequests, isEmpty);
  });

  testWidgets('List supports exact reference without scanner', (tester) async {
    final api = FakeTicketApi();
    api.listLoader = () async => [sample(), sample(reference: 'ABI-PAID', status: 'paid'), sample(reference: 'ABI-CANCELLED', status: 'cancelled'), sample(reference: 'ABI-OVERDUE', overdue: true)];
    api.detailLoader = (reference) async => sample();
    final tickets = TicketSession(api);
    final org = OrgSession(tickets);
    addTearDown(tickets.dispose);
    addTearDown(org.dispose);
    await tester.pumpWidget(MaterialApp(home: OrgScreen(session: org)));
    await tester.pumpAndSettle();
    await show(tester, find.byKey(const Key('reservation-reference')));
    await tester.enterText(find.byKey(const Key('reservation-reference')), '  ABI-ORG-123  ');
    await show(tester, find.text('Referenz öffnen'));
    await tester.tap(find.text('Referenz öffnen'));
    await tester.pumpAndSettle();
    expect(api.detailRequests.last, 'ABI-ORG-123');
    expect(find.text('Reservierung verwalten'), findsOneWidget);
  });

  testWidgets('Payment refreshes dashboard on return without restarting app', (tester) async {
    final api = FullOrgApi();
    await tester.pumpWidget(AppiApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('0,00 €'), findsOneWidget);
    await show(tester, find.text('Org-Team'));
    await tester.tap(find.text('Org-Team'));
    await tester.pumpAndSettle();
    await show(tester, find.byKey(const ValueKey('org-ABI-ORG-123')));
    await tester.tap(find.byKey(const ValueKey('org-ABI-ORG-123')));
    await tester.pumpAndSettle();
    await show(tester, find.byKey(const Key('payment-action')));
    await tester.tap(find.byKey(const Key('payment-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-org-change')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('90,00 €'), findsOneWidget);
  });
  testWidgets('List failure is visible and can be retried without showing a guessed empty list', (tester) async {
    final api = FakeTicketApi();
    api.listLoader = () async => throw const TicketFailure('Backend nicht erreichbar.');
    final tickets = TicketSession(api);
    final org = OrgSession(tickets);
    addTearDown(tickets.dispose);
    addTearDown(org.dispose);
    await tester.pumpWidget(MaterialApp(home: OrgScreen(session: org)));
    await tester.pumpAndSettle();
    await show(tester, find.text('Backend nicht erreichbar.'));
    expect(find.text('Backend nicht erreichbar.'), findsOneWidget);
    expect(find.text('Noch keine Reservierungen vorhanden.'), findsNothing);
    api.listLoader = () async => [];
    await show(tester, find.byKey(const Key('load-reservations')));
    await tester.tap(find.byKey(const Key('load-reservations')));
    await tester.pumpAndSettle();
    await show(tester, find.text('Noch keine Reservierungen vorhanden.'));
    expect(find.text('Noch keine Reservierungen vorhanden.'), findsOneWidget);
  });

  testWidgets('Status display separates open, paid, cancelled and overdue cases', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      ReservationStatus(sample()), ReservationStatus(sample(status: 'paid')),
      ReservationStatus(sample(status: 'cancelled')), ReservationStatus(sample(overdue: true)),
    ]))));
    for (final label in ['Reserviert · noch nicht bezahlt', 'Bezahlt', 'Storniert', 'Überfällig · weiter reserviert']) {
      expect(find.text(label), findsOneWidget);
    }
  });

}
