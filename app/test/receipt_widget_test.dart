import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appi/screens/receipt.dart';
import 'package:appi/tickets.dart';

void main() {
  testWidgets('Loads the PDF before preview and shares exactly those bytes', (tester) async {
    final pending = Completer<Uint8List>();
    final bytes = Uint8List.fromList('%PDF-1.4 test-document'.codeUnits);
    Uint8List? previewed, shared;
    String? filename;
    Rect? anchor;
    await tester.pumpWidget(MaterialApp(home: ReceiptScreen(
      reference: 'ABI-DEMO-123', load: () => pending.future,
      previewBuilder: (context, data) {
        previewed = data;
        return const Text('Rendered test document');
      },
      share: (data, name, bounds) async {
        shared = data;
        filename = name;
        anchor = bounds;
      },
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('share-receipt'))).onPressed, isNull);
    pending.complete(bytes);
    await tester.pumpAndSettle();
    expect(previewed, same(bytes));
    expect(find.text('Rendered test document'), findsOneWidget);
    await tester.tap(find.byTooltip('PDF teilen'));
    await tester.pumpAndSettle();
    expect(shared, same(bytes));
    expect(filename, 'PMG-AppI-Reservierung-ABI-DEMO-123.pdf');
    expect(anchor!.width, greaterThan(0));
    expect(anchor!.height, greaterThan(0));
  });

  testWidgets('Load failure disables sharing; retry loads document without booking again', (tester) async {
    int calls = 0;
    await tester.pumpWidget(MaterialApp(home: ReceiptScreen(
      reference: 'ABI-DEMO-123',
      load: () async {
        calls++;
        if (calls == 1) throw const TicketFailure('Backend nicht erreichbar.');
        return Uint8List.fromList('%PDF-1.4 test'.codeUnits);
      },
      previewBuilder: (_, bytes) => const Text('PDF ready'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Backend nicht erreichbar.'), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('share-receipt'))).onPressed, isNull);
    await tester.tap(find.text('Beleg erneut laden'));
    await tester.pumpAndSettle();
    expect(find.text('PDF ready'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('Share failure retains preview and permits another attempt', (tester) async {
    int attempts = 0;
    await tester.pumpWidget(MaterialApp(home: ReceiptScreen(
      reference: 'ABI-DEMO-123', load: () async => Uint8List.fromList('%PDF-1.4 test'.codeUnits),
      previewBuilder: (_, bytes) => const Text('PDF ready'),
      share: (_, filename, bounds) async {
        attempts++;
        throw Exception('Native share failed');
      },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('PDF teilen'));
    await tester.pumpAndSettle();
    expect(find.text('PDF ready'), findsOneWidget);
    expect(find.textContaining('Teilen konnte nicht geöffnet werden.'), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('share-receipt'))).onPressed, isNotNull);
    expect(attempts, 1);
  });
}
