import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appi/api.dart';
import 'package:appi/main.dart';

class FakeApi implements AppiApi {
  final result = Completer<SchoolConfig>();
  @override
  Future<SchoolConfig> loadConfig() => result.future;
  @override
  void close() {}
}

void main() {
  testWidgets(
    'Splash transitions to configured home without artificial delay',
    (tester) async {
      final api = FakeApi();
      await tester.pumpWidget(AppiApp(api: api));
      expect(find.text('Jahrgang wird geladen …'), findsOneWidget);
      api.result.complete(
        const SchoolConfig(school: 'Demo Schule', year: 2028),
      );
      await tester.pumpAndSettle();
      expect(find.text('PMG AppI'), findsOneWidget);
      expect(find.text('Abiturjahrgang 2028'), findsOneWidget);
      expect(find.text('Demo Schule'), findsOneWidget);
      expect(find.text('Lokales Backend verbunden'), findsOneWidget);
    },
  );

  testWidgets(
    'Backend error is visible and preview navigation remains available',
    (tester) async {
      final api = FakeApi();
      await tester.pumpWidget(AppiApp(api: api));
      api.result.completeError(const ApiFailure('Bitte Backend starten.'));
      await tester.pumpAndSettle();
      expect(find.text('Bitte Backend starten.'), findsOneWidget);
      expect(find.text('Erneut versuchen'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Kiosk'), 200);
      await tester.tap(find.text('Kiosk'));
      await tester.pumpAndSettle();
      expect(find.text('Beispielangebot'), findsOneWidget);
      await tester.tap(find.text('Beispielangebot'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Brezel'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Backend nicht verbunden'), findsOneWidget);
    },
  );

  testWidgets(
    'Large text on a narrow screen remains scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeApi();
      api.result.complete(
        const SchoolConfig(school: 'Demo Schule', year: 2027),
      );
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(AppiApp(api: api));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
