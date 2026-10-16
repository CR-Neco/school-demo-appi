import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../tickets.dart';

typedef ReceiptPreviewBuilder = Widget Function(BuildContext context, Uint8List bytes);
typedef ReceiptSharer = Future<void> Function(Uint8List bytes, String filename, Rect bounds);

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.reference, required this.load,
    this.previewBuilder, this.share});
  final String reference;
  final Future<Uint8List> Function() load;
  // Inject platform boundaries in widget tests; production uses the actual plugin.
  final ReceiptPreviewBuilder? previewBuilder;
  final ReceiptSharer? share;
  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  Uint8List? _bytes;
  String? _error, _shareError;
  bool _loading = true, _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _bytes = null; _error = null; _shareError = null; });
    try {
      final bytes = await widget.load();
      if (mounted) setState(() { _bytes = bytes; });
    } catch (error) {
      if (mounted) setState(() {
        _error = error is TicketFailure ? error.message : 'PDF-Beleg konnte nicht geladen werden.';
      });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  String get _filename {
    final safe = widget.reference.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'PMG-AppI-Reservierung-$safe.pdf';
  }

  Future<void> _share(BuildContext buttonContext) async {
    final bytes = _bytes;
    if (bytes == null || _sharing) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final bounds = box == null ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() { _sharing = true; _shareError = null; });
    try {
      final share = widget.share;
      if (share != null) {
        await share(bytes, _filename, bounds);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: _filename, bounds: bounds);
      }
    } catch (_) {
      if (mounted) setState(() { _shareError = 'Teilen konnte nicht geöffnet werden. Bitte die App vollständig neu starten und erneut versuchen.'; });
    } finally {
      if (mounted) setState(() { _sharing = false; });
    }
  }

  Widget _preview(Uint8List bytes) {
    final custom = widget.previewBuilder;
    if (custom != null) return custom(context, bytes);
    return PdfPreview(
      build: (_) async => bytes,
      pdfFileName: _filename,
      allowPrinting: false, allowSharing: false, useActions: false,
      canChangePageFormat: false, canChangeOrientation: false, canDebug: false,
      dynamicLayout: false,
      onError: (context, error) => Center(child: Padding(
        padding: const EdgeInsets.all(24), child: Text(
          'Die PDF-Vorschau konnte nicht gerendert werden. Starte die App vollständig neu. Den geladenen Beleg kannst du über „PDF teilen“ öffnen.',
          textAlign: TextAlign.center))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return Scaffold(
      appBar: AppBar(title: const Text('Reservierungsbeleg'), actions: [
        Builder(builder: (buttonContext) => IconButton(
          key: const Key('share-receipt'), tooltip: 'PDF teilen',
          onPressed: bytes == null || _sharing ? null : () => _share(buttonContext),
          icon: const Icon(Icons.ios_share))),
      ]),
      body: Column(children: [
        const Padding(padding: EdgeInsets.fromLTRB(18, 12, 18, 12), child: Text(
          'Demo-Beleg · noch keine Eintrittskarte. Bankdaten sind fiktiv. Der QR-Demo-Link kann hier nicht geöffnet werden.',
          style: TextStyle(fontSize: 12))),
        if (_shareError != null) Padding(padding: const EdgeInsets.all(16), child: Text(_shareError!)),
        if (_sharing) const LinearProgressIndicator(),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
          : _error != null ? Center(child: SingleChildScrollView(child: Padding(
              padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Beleg erneut laden')),
              ]))))
          : bytes != null ? _preview(bytes) : const SizedBox.shrink()),
      ]),
    );
  }
}
