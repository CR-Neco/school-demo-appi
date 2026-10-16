import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:appi/org.dart';
import 'package:appi/tickets.dart';

import 'support/ticket_fake.dart';

import 'support/org_sample.dart';

void main() {
  test('Org status keeps overdue reservations distinct from paid/cancelled', () {
    expect(sample(overdue: true).statusLabel, 'Überfällig · weiter reserviert');
    expect(sample(status: 'paid', overdue: true).statusLabel, 'Bezahlt');
    expect(sample(status: 'cancelled').isOpen, isFalse);
  });

  test('Payment changes the model and ticket confirmation only after backend success', () async {
    final api = FakeTicketApi();
    api.detailLoader = (_) async => sample();
    final pending = Completer<Reservation>();
    api.paymentHandler = (_) => pending.future;
    final tickets = TicketSession(api)..reservation = sample();
    final org = OrgSession(tickets);
    addTearDown(tickets.dispose);
    addTearDown(org.dispose);
    final admin = org.detail('ABI-ORG-123');
    await admin.load();
    final saving = admin.change(OrgAction.payment);
    await admin.change(OrgAction.payment);
    expect(api.paymentRequests, hasLength(1));
    expect(admin.current!.status, 'reserved');
    expect(tickets.reservation!.status, 'reserved');
    pending.complete(sample(status: 'paid'));
    await saving;
    expect(admin.current!.status, 'paid');
    expect(tickets.reservation!.status, 'paid');
    expect(admin.canChange, isFalse);
  });

  test('Unclear extension retries unchanged even after an auth error and route reopen', () async {
    final api = FakeTicketApi();
    api.detailLoader = (_) async => sample();
    api.extendHandler = (_, days, key) async => throw const TicketFailure('Antwort unklar', outcomeUnknown: true);
    final tickets = TicketSession(api);
    final org = OrgSession(tickets);
    addTearDown(tickets.dispose);
    addTearDown(org.dispose);
    final admin = org.detail('ABI-ORG-123');
    await admin.load();
    await admin.change(OrgAction.extend);
    final id = api.extensionIds.single;
    expect(admin.pending!.days, 3);
    expect(org.detail('ABI-ORG-123'), same(admin));
    api.extendHandler = (_, days, key) async => throw const TicketFailure('Token falsch');
    await admin.retry();
    expect(admin.pending, isNotNull);
    await admin.load();
    expect(admin.canChange, isFalse);
    api.extendHandler = (_, days, key) async => sample(deadline: DateTime.utc(2027, 6, 4, 18));
    await admin.retry();
    expect(api.extensionIds, [id, id, id]);
    expect(admin.current!.expiresAt, DateTime.utc(2027, 6, 4, 18));
    expect(admin.pending, isNull);
  });

  test('Definite conflict shows error and requires reloading current state', () async {
    final api = FakeTicketApi();
    api.detailLoader = (_) async => sample();
    api.cancelHandler = (_) async => throw const TicketFailure('Bereits bezahlt.', code: 'invalid_state');
    final admin = ReservationAdmin(api, 'ABI-ORG-123');
    addTearDown(admin.dispose);
    await admin.load();
    await admin.change(OrgAction.cancel);
    expect(admin.changeError, 'Bereits bezahlt.');
    expect(admin.pending, isNull);
    expect(admin.canChange, isFalse);
    api.detailLoader = (_) async => sample(status: 'paid');
    await admin.load();
    expect(admin.current!.status, 'paid');
    expect(admin.changeError, 'Bereits bezahlt.');
  });
}
