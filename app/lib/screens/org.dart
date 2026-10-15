import 'package:flutter/material.dart';

import '../fundraising.dart';
import '../org.dart';
import '../tickets.dart';
import '../widgets/components.dart';
import 'receipt.dart';

class OrgScreen extends StatefulWidget {
  const OrgScreen({super.key, required this.session});
  final OrgSession session;
  @override
  State<OrgScreen> createState() => _OrgScreenState();
}

class _OrgScreenState extends State<OrgScreen> {
  late final TextEditingController _token;
  final _reference = TextEditingController();
  List<Reservation>? _items;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _token = TextEditingController(text: widget.session.api.orgToken);
    if (_token.text.trim().isNotEmpty) _load();
  }

  @override
  void dispose() {
    _token.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    widget.session.api.orgToken = _token.text.trim();
    if (widget.session.api.orgToken.isEmpty) {
      setState(() { _error = 'Bitte den lokalen Demo-Token einfügen.'; _items = null; });
      return;
    }
    setState(() { _loading = true; _error = null; _items = null; });
    try {
      final items = await widget.session.api.loadReservations();
      if (mounted) setState(() { _items = items; });
    } catch (error) {
      if (mounted) setState(() { _error = error is TicketFailure ? error.message : 'Reservierungen konnten nicht geladen werden.'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _open(String reference) async {
    final value = reference.trim();
    widget.session.api.orgToken = _token.text.trim();
    if (value.isEmpty || widget.session.api.orgToken.isEmpty) {
      setState(() { _error = 'Bitte Demo-Zugang und Reservierungsnummer eingeben.'; });
      return;
    }
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OrgReservationScreen(
      admin: widget.session.detail(value), api: widget.session.api)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Org-Team')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(padding: const EdgeInsets.all(22), children: [
        const Wrap(spacing: 8, children: [InfoChip('DEMO-ORG-ZUGANG'), InfoChip('Keine Bankanbindung')]),
        const SizedBox(height: 16),
        const Text('Karten & Abikasse', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Hier gleicht das Finanzteam den Kontoauszug mit Reservierungen ab. Die Zahlung wird bewusst von euch bestätigt.'),
        const SizedBox(height: 12),
        ExpansionTile(initiallyExpanded: _token.text.trim().isEmpty,
          title: const Text('Lokaler Demo-Zugang'), childrenPadding: const EdgeInsets.only(bottom: 16), children: [
            const Text('Derselbe lokale Token wie beim Kartenverkauf. Er bleibt nur für diesen App-Lauf gespeichert.'),
            const SizedBox(height: 10),
            TextField(key: const Key('admin-token'), controller: _token, obscureText: true,
              enableSuggestions: false, autocorrect: false,
              decoration: const InputDecoration(labelText: 'Demo-Token', border: OutlineInputBorder())),
          ]),
        FilledButton.icon(key: const Key('load-reservations'), onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh), label: const Text('Reservierungen laden')),
        const SizedBox(height: 22),
        TextField(key: const Key('reservation-reference'), controller: _reference,
          textInputAction: TextInputAction.go, autocorrect: false,
          onSubmitted: _open,
          decoration: const InputDecoration(labelText: 'Reservierungsnummer', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => _open(_reference.text), child: const Text('Referenz öffnen')),
        const SizedBox(height: 16),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_error!, style: const TextStyle(color: Color(0xFF9A3412)))),
        if (_items != null && _items!.isEmpty) const Text('Noch keine Reservierungen vorhanden.'),
        if (_items != null) ...[
          Text('${_items!.length} Reservierungen', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          for (final item in _items!) Card(child: InkWell(
            key: ValueKey('org-${item.reference}'), onTap: () => _open(item.reference),
            child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 6),
              ReservationStatus(item),
              const SizedBox(height: 6),
              Text('${item.quantity} Karten · ${euro(item.totalCents)}'),
              Text(item.reference, style: const TextStyle(fontSize: 12)),
              Text('Frist: ${reservationDeadline(item.expiresAt)}', style: const TextStyle(fontSize: 12)),
            ])),
          )),
        ],
        const SizedBox(height: 24),
        const ExpandableInfo(title: 'Kontakt im Demo-Team',
          body: 'Sam Beispiel · Karten & Abikasse\nAlex Beispiel · Kiosk & Verkaufsstände\nAlle Namen sind fiktiv.'),
        const SizedBox(height: 20),
      ]),
    )),
  );
}

class ReservationStatus extends StatelessWidget {
  const ReservationStatus(this.value, {super.key});
  final Reservation value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: switch (value.status) {
      'paid' => const Color(0xFFDDF49C), 'cancelled' => const Color(0xFFE4E7E9),
      _ => value.overdue ? const Color(0xFFF9D8B9) : const Color(0xFFD5DEF6),
    }),
    child: Text(value.statusLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
  );
}

class OrgReservationScreen extends StatefulWidget {
  const OrgReservationScreen({super.key, required this.admin, required this.api});
  final ReservationAdmin admin;
  final TicketApi api;
  @override
  State<OrgReservationScreen> createState() => _OrgReservationScreenState();
}

class _OrgReservationScreenState extends State<OrgReservationScreen> {
  ReservationAdmin get admin => widget.admin;
  bool _confirming = false;
  @override
  void initState() {
    super.initState();
    admin.addListener(_changed);
    admin.load();
  }
  void _changed() { if (mounted) setState(() {}); }
  @override
  void dispose() {
    admin.removeListener(_changed);
    super.dispose();
  }

  Future<void> _confirm(OrgAction action, {bool retry = false}) async {
    if (_confirming || admin.busy) return;
    setState(() { _confirming = true; });
    final value = admin.current;
    final title = switch (action) {
      OrgAction.payment => 'Zahlungseingang bestätigen?',
      OrgAction.cancel => 'Reservierung stornieren?',
      OrgAction.extend => 'Frist um 3 Tage verlängern?',
    };
    final text = switch (action) {
      OrgAction.payment => 'Hast du den vollständigen Eingang von ${value == null ? "dem Betrag" : euro(value.totalCents)} für ${value?.name ?? admin.reference} auf dem Konto geprüft? Erst dann wird der Betrag in der Abikasse berücksichtigt.',
      OrgAction.cancel => 'Die reservierten Karten werden wieder freigegeben. Diese Reservierung kann danach nicht mehr bezahlt werden.',
      OrgAction.extend => 'Die Frist wird um 3 Tage ab dem späteren Zeitpunkt von jetzt und bisherigem Ablauf verlängert. Es werden keine zusätzlichen Karten reserviert.',
    };
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(title), content: SingleChildScrollView(child: Text(retry ? '$text\n\nDies ist die sichere Wiederholung derselben Änderung.' : text)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
        FilledButton(key: const Key('confirm-org-change'), onPressed: () => Navigator.pop(context, true), child: const Text('Bestätigen')),
      ],
    ));
    if (!mounted) return;
    setState(() { _confirming = false; });
    if (confirmed != true) return;
    if (retry) { await admin.retry(); } else { await admin.change(action); }
  }

  @override
  Widget build(BuildContext context) {
    final value = admin.current;
    final enabled = admin.canChange && !_confirming;
    return PopScope(canPop: !admin.working, child: Scaffold(
      appBar: AppBar(title: const Text('Reservierung verwalten')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(padding: const EdgeInsets.all(22), children: [
          const InfoChip('DEMO-ORG-ZUGANG'),
          const SizedBox(height: 14),
          const Text('Reservierungsnummer', style: TextStyle(fontWeight: FontWeight.bold)),
          SelectableText(admin.reference),
          const SizedBox(height: 16),
          if (admin.busy) const LinearProgressIndicator(),
          if (admin.loadError != null) Text(admin.loadError!, style: const TextStyle(color: Color(0xFF9A3412))),
          if (value != null) ...[
            Text(value.name, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ReservationStatus(value),
            const SizedBox(height: 14),
            Text('${value.quantity} Karten · ${euro(value.totalCents)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text('Einzelpreis: ${euro(value.priceCents)}'),
            const SizedBox(height: 8),
            Text('Zahlungsfrist: ${reservationDeadline(value.expiresAt)}'),
            if (value.overdue && value.isOpen) const Padding(padding: EdgeInsets.only(top: 10),
              child: Text('Die Frist ist überschritten. Die Karten bleiben reserviert, bis ihr verlängert, storniert oder eine Zahlung bestätigt.')),
            if (admin.working || admin.pending != null || admin.loadError != null || admin.requiresReload)
              const Padding(padding: EdgeInsets.only(top: 12), child: Text('Angezeigt ist der zuletzt bestätigte Stand.')),
          ],
          const SizedBox(height: 14),
          if (admin.changeError != null) Text(admin.changeError!, style: const TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.bold)),
          if (admin.notice != null) Text(admin.notice!, style: const TextStyle(color: Color(0xFF487552))),
          if (admin.pending != null && !admin.working) ...[
            const SizedBox(height: 12),
            Text('Antwort unklar: ${admin.pending!.label}. Andere Änderungen bleiben gesperrt. Erneutes Senden wiederholt dieselbe Aktion.'),
            FilledButton(key: const Key('retry-org-change'), onPressed: admin.busy || _confirming ? null : () => _confirm(admin.pending!.action, retry: true),
              child: const Text('Dieselbe Änderung erneut senden')),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: admin.busy || _confirming ? null : admin.load,
            icon: const Icon(Icons.refresh), label: const Text('Aktuellen Stand laden')),
          const SizedBox(height: 18),
          if (value?.isOpen == true) ...[
            FilledButton.icon(key: const Key('payment-action'), onPressed: enabled ? () => _confirm(OrgAction.payment) : null,
              icon: const Icon(Icons.payments_outlined), label: const Text('Zahlung bestätigen')),
            const SizedBox(height: 10),
            OutlinedButton(key: const Key('extend-action'), onPressed: enabled ? () => _confirm(OrgAction.extend) : null,
              child: const Text('Um 3 Tage verlängern')),
            const SizedBox(height: 10),
            TextButton(key: const Key('cancel-action'), onPressed: enabled ? () => _confirm(OrgAction.cancel) : null,
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF9A3412)), child: const Text('Reservierung stornieren')),
          ],
          if (value != null) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(onPressed: admin.busy || _confirming ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ReceiptScreen(reference: value.reference, load: () => widget.api.loadReceipt(value.reference)))),
              icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('PDF-Beleg öffnen')),
          ],
          const SizedBox(height: 20),
        ]),
      )),
    ));
  }
}
