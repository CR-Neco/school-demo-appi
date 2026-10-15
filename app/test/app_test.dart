import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appi/api.dart';
import 'package:appi/fundraising.dart';
import 'package:appi/main.dart';
import 'package:appi/widgets/fundraising_card.dart';

class FakeApi implements AppiApi {
  final result = Completer<SchoolConfig>();
  int dashboardCalls = 0;
  Future<Fundraising> Function() dashboardLoader = () async =>
      const Fundraising(targetCents: 1500000, raisedCents: 0);
  @override
  Future<SchoolConfig> loadConfig() => result.future;
  @override
  Future<Fundraising> loadDashboard() {
    dashboardCalls++;
    return dashboardLoader();
  }
  @override
  void close() {}
}

Future<void> show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> start(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AppiApp(api: api));
  api.result.complete(const SchoolConfig(school: 'Demo Schule', year: 2028));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Splash transitions without artificial delay; name is year independent', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(AppiApp(api: api));
    expect(find.text('Jahrgang wird geladen …'), findsOneWidget);
    api.result.complete(const SchoolConfig(school: 'Demo Schule', year: 2028));
    await tester.pumpAndSettle();
    expect(find.text('PMG AppI'), findsOneWidget);
    expect(find.text('Abiturjahrgang 2028'), findsOneWidget);
    expect(find.text('Fundraising Abi 2028'), findsOneWidget);
    expect(find.text('Demo Schule'), findsOneWidget);
    expect(find.text('0,00 €'), findsOneWidget);
  });

  testWidgets('Config error does not block preview navigation', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(AppiApp(api: api));
    api.result.completeError(const ApiFailure('Bitte Backend starten.'));
    await tester.pumpAndSettle();
    await show(tester, find.text('Bitte Backend starten.'));
    expect(find.text('Schuldaten nicht verfügbar'), findsOneWidget);
    await show(tester, find.text('Kiosk'));
    await tester.tap(find.text('Kiosk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beispielangebot'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Brezel'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(api.dashboardCalls, 2);
  });

  testWidgets('Refresh hides stale totals on failure and retry restores actual totals', (tester) async {
    final api = FakeApi();
    api.dashboardLoader = () async => const Fundraising(targetCents: 10000, raisedCents: 2500);
    await start(tester, api);
    expect(find.text('25,00 €'), findsOneWidget);
    api.dashboardLoader = () async => throw const ApiFailure('Keine Verbindung.');
    await tester.tap(find.byTooltip('Finanzierungsstand aktualisieren'));
    await tester.pumpAndSettle();
    expect(find.text('Finanzierungsstand nicht verfügbar'), findsOneWidget);
    expect(find.text('25,00 €'), findsNothing);
    api.dashboardLoader = () async => const Fundraising(targetCents: 10000, raisedCents: 4500);
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();
    expect(find.text('45,00 €'), findsOneWidget);
    expect(find.text('45,0 % erreicht'), findsOneWidget);
  });

  testWidgets('Returning from a section reloads ledger totals without restarting app', (tester) async {
    final api = FakeApi();
    await start(tester, api);
    await show(tester, find.text('Org-Team'));
    await tester.tap(find.text('Org-Team'));
    await tester.pumpAndSettle();
    // Represents a confirmed backend payment while the org screen is open.
    api.dashboardLoader = () async => const Fundraising(targetCents: 1500000, raisedCents: 9000);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('raised-amount')), -250);
    expect(find.text('90,00 €'), findsOneWidget);
    expect(api.dashboardCalls, 2);
  });

  testWidgets('Loading never displays a guessed zero balance', (tester) async {
    final api = FakeApi();
    final pending = Completer<Fundraising>();
    api.dashboardLoader = () => pending.future;
    await tester.pumpWidget(AppiApp(api: api));
    api.result.complete(const SchoolConfig(school: 'Demo Schule', year: 2028));
    await tester.pump();
    await tester.pump();
    expect(find.text('Finanzierungsstand wird geladen …'), findsOneWidget);
    expect(find.text('0,00 €'), findsNothing);
    pending.complete(const Fundraising(targetCents: 10000, raisedCents: 3500));
    await tester.pumpAndSettle();
    expect(find.text('35,00 €'), findsOneWidget);
  });

  testWidgets('Funding card handles a narrow screen and large text', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
      child: Scaffold(body: SingleChildScrollView(child: FundraisingCard(
        year: 2028, data: const Fundraising(targetCents: 1500000, raisedCents: 1723456),
        loading: false, error: null, onRefresh: () {},
      ))),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Ziel erreicht!'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(find.byKey(const Key('fundraising-progress')));
    expect(bar.value, 1.0);
  });

  testWidgets('Invalid target displays explanation instead of invalid percentage', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FundraisingCard(
      year: 2028, data: const Fundraising(targetCents: 0, raisedCents: 9000),
      loading: false, error: null, onRefresh: () {},
    ))));
    expect(find.text('Ziel noch nicht festgelegt'), findsOneWidget);
    expect(find.textContaining('NaN'), findsNothing);
    expect(find.textContaining('Infinity'), findsNothing);
  });
}
