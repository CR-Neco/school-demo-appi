import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appi/demo_content.dart';
import 'package:appi/api.dart';
import 'package:appi/fundraising.dart';
import 'package:appi/main.dart';
import 'package:appi/screens/demo_sections.dart';
import 'package:appi/tickets.dart';

import 'support/demo_content_sample.dart';

class FakeContentApi implements DemoContentApi {
  bool fail = false;
  @override
  Future<DemoContent> loadDemoContent() async {
    if (fail) throw const TicketFailure('Backend nicht erreichbar.');
    return sampleContent;
  }
}

class FullContentApi extends FakeContentApi implements AppiApi {
  @override
  Future<SchoolConfig> loadConfig() async => const SchoolConfig(school: 'Demo Schule', year: 2027);
  @override
  Future<Fundraising> loadDashboard() async => const Fundraising(targetCents: 1500000, raisedCents: 175500);
  @override
  void close() {}
}

Future<void> show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 160, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('Finance validates net amounts and supports actual negative balances', () {
    expect(DemoFinance.fromJson({'income_cents': 100, 'expenses_cents': 250, 'raised_cents': -150}).raisedCents, -150);
    expect(() => DemoFinance.fromJson({'income_cents': 100, 'expenses_cents': 250, 'raised_cents': 999}), throwsFormatException);
    expect(() => DemoContent.fromJson({'is_demo': false}), throwsFormatException);
  });

  testWidgets('Dashboard routes kiosk and stands to their populated demo screens', (tester) async {
    await tester.pumpWidget(AppiApp(api: FullContentApi()));
    await tester.pumpAndSettle();
    await show(tester, find.text('Kiosk'));
    await tester.tap(find.text('Kiosk'));
    await tester.pumpAndSettle();
    expect(find.text('Schulkiosk'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await show(tester, find.text('Verkaufsstände'));
    await tester.tap(find.text('Verkaufsstände'));
    await tester.pumpAndSettle();
    expect(find.text('Schulfest'), findsOneWidget);
  });

  testWidgets('Kiosk shows products, current net and expandable shift note', (tester) async {
    await tester.pumpWidget(MaterialApp(home: DemoSectionsScreen(api: FakeContentApi(), kiosk: true)));
    await tester.pumpAndSettle();
    await show(tester, find.text('600,00 €'));
    expect(find.text('600,00 €'), findsOneWidget);
    await show(tester, find.text('Kaffee'));
    expect(find.text('1,50 €'), findsOneWidget);
    await show(tester, find.text('Die nächste Schicht'));
    await tester.tap(find.text('Die nächste Schicht'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Alex & Jamie'), findsOneWidget);
  });

  testWidgets('Sales stand shows fictional date and consistent action contribution', (tester) async {
    await tester.pumpWidget(MaterialApp(home: DemoSectionsScreen(api: FakeContentApi(), kiosk: false)));
    await tester.pumpAndSettle();
    expect(find.text('Schulfest'), findsOneWidget);
    expect(find.textContaining('Beispiel: 12. Juni'), findsOneWidget);
    await show(tester, find.text('540,00 €'));
    expect(find.text('540,00 €'), findsOneWidget);
    await show(tester, find.text('Was brauchen wir dafür?'));
    await tester.tap(find.text('Was brauchen wir dafür?'));
    await tester.pumpAndSettle();
    expect(find.text('Wer hilft beim Aufbau?'), findsOneWidget);
  });

  testWidgets('Backend failure hides amounts and supports retry', (tester) async {
    final api = FakeContentApi()..fail = true;
    await tester.pumpWidget(MaterialApp(home: DemoSectionsScreen(api: api, kiosk: true)));
    await tester.pumpAndSettle();
    expect(find.text('Backend nicht erreichbar.'), findsOneWidget);
    expect(find.text('600,00 €'), findsNothing);
    api.fail = false;
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();
    await show(tester, find.text('600,00 €'));
    expect(find.text('600,00 €'), findsOneWidget);
  });

  testWidgets('Kiosk works on a narrow screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
      child: DemoSectionsScreen(api: FakeContentApi(), kiosk: true))));
    await tester.pumpAndSettle();
    await show(tester, find.text('Die nächste Schicht'));
    expect(tester.takeException(), isNull);
  });
}
