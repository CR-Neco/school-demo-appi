import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appi/widgets/brand_splash.dart';

void main() {
  testWidgets('Splash stays usable on a narrow display with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(2)),
      child: BrandSplash(),
    )));
    // The progress indicator deliberately keeps animating until config arrives.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('PMG AppI'), findsOneWidget);
    await tester.ensureVisible(find.text('Jahrgang wird geladen …'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('2027'), findsNothing);
  });

  testWidgets('Bundled branding images decode without network access', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox(key: Key('asset-context'))));
    final context = tester.element(find.byKey(const Key('asset-context')));
    await tester.runAsync(() async {
      for (final path in [
        'assets/branding/pmg-logo.png',
        'assets/branding/pmg-campus.jpg',
        'assets/branding/splash-students.jpg',
        'assets/branding/app-icon.png',
      ]) {
        await precacheImage(AssetImage(path), context,
          onError: (error, stack) => fail('Cannot decode $path: $error'));
      }
    });
  });
}
