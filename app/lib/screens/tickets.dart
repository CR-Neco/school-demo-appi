import 'package:flutter/material.dart';

import '../fundraising.dart';
import '../tickets.dart';
import '../widgets/components.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key, required this.session, required this.year});
  final TicketSession session;
  final int year;
  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _token;
  TicketSale? _sale;
  TicketStock? _stock;
  String? _loadError, _stockError;
  bool _loading = true, _refreshing = false;
  String? _seenReference;
  int _stockVersion = 0;
  TicketSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: session.pending?.name ?? '');
    _quantity = TextEditingController(text: '${session.pending?.quantity ?? 1}');
    _token = TextEditingController(text: session.api.orgToken);
    _seenReference = session.reservation?.reference;
    session.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    session.removeListener(_changed);
    _name.dispose();
    _quantity.dispose();
    _token.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final reference = session.reservation?.reference;
    if (reference != null && reference != _seenReference) {
      _seenReference = reference;
      _refreshStock();
    }
  }

  Future<void> _load() async {
    final stockVersion = ++_stockVersion;
    setState(() { _loading = true; _loadError = null; });
    try {
      final sale = await session.api.loadTicketSale();
      if (!mounted) return;
      setState(() {
        _sale = sale;
        if (stockVersion == _stockVersion) { _stock = sale.stock; _stockError = null; }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loadError = _message(error); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _refreshStock() async {
    final eventId = _sale?.eventId ?? session.reservation?.eventId ?? session.pending?.eventId;
    if (eventId == null || _refreshing) return;
    final stockVersion = ++_stockVersion;
    setState(() { _refreshing = true; _stockError = null; });
    try {
      final stock = await session.api.loadTicketStock(eventId);
      if (mounted && stockVersion == _stockVersion) setState(() { _stock = stock; });
    } catch (error) {
      if (mounted && stockVersion == _stockVersion) setState(() { _stock = null; _stockError = _message(error); });
    } finally {
      if (mounted) setState(() { _refreshing = false; });
    }
  }

  String _message(Object error) => error is TicketFailure
      ? error.message : 'Die Daten konnten nicht geladen werden. Bitte erneut versuchen.';

  Future<void> _submit() async {
    if (session.submitting || _refreshing || _loading) return;
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    session.api.orgToken = _token.text.trim();
    final eventId = session.pending?.eventId ?? _sale?.eventId;
    if (eventId == null) return;
    await session.submit(eventId: eventId, name: _name.text,
      quantity: int.parse(_quantity.text.trim()));
    if (!mounted) return;
    if (session.reservation == null) await _refreshStock();
  }

  void _newOrder() {
    session.newOrder();
    _name.clear();
    _quantity.text = '1';
    _form.currentState?.reset();
    _refreshStock();
  }

  @override
  Widget build(BuildContext context) {
    final reservation = session.reservation;
    final locked = session.pending != null || session.submitting;
    final quantity = int.tryParse(_quantity.text.trim());
    final sale = _sale;
    return Scaffold(
      appBar: AppBar(title: const Text('Abiball-Tickets')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(padding: const EdgeInsets.all(22), children: [
          const Wrap(spacing: 8, children: [InfoChip('LOKALE DEMO'), InfoChip('Keine echten Buchungen')]),
          const SizedBox(height: 12),
          Text('Euer Abiball ${widget.year}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Beispieltermin: 26. Juni ${widget.year} · 18 Uhr\nBeispielort: Festsaal Meine. Alle Veranstaltungsdaten sind fiktiv.',
            style: const TextStyle(color: Color(0xFF617079), height: 1.5)),
          const SizedBox(height: 18),
          if (_loading) const LinearProgressIndicator(),
          if (_loadError != null) ...[
            _notice(_loadError!),
            TextButton(onPressed: _loading ? null : _load, child: const Text('Veranstaltung erneut laden')),
          ],
          if (sale != null) Text('${euro(sale.priceCents)} pro Karte · Reservierung für ${sale.reservationDays} Tage',
            style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Kartenkontingent', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_refreshing) const LinearProgressIndicator(minHeight: 2)
              else if (_stock != null) Text('${_stock!.available} verfügbar · ${_stock!.reserved} reserviert · ${_stock!.paid} bezahlt'),
              if (_stockError != null) Text(_stockError!),
              TextButton.icon(onPressed: _refreshing || _loading || session.submitting ? null : _refreshStock,
                icon: const Icon(Icons.refresh), label: const Text('Verfügbarkeit aktualisieren')),
            ],
          ))),
          const SizedBox(height: 18),
          if (reservation != null) ...[
            _confirmation(reservation),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _newOrder, child: const Text('Weitere Reservierung')),
          ] else if (sale != null || session.pending != null) Form(key: _form, child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Für wen reservieren wir?', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextFormField(key: const Key('buyer-name'), controller: _name, readOnly: locked,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.words, validator: validateBuyerName),
              const SizedBox(height: 14),
              TextFormField(key: const Key('ticket-quantity'), controller: _quantity, readOnly: locked,
                keyboardType: TextInputType.number, validator: validateTicketQuantity,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Kartenanzahl', border: OutlineInputBorder())),
              const SizedBox(height: 14),
              if (sale != null && quantity != null && quantity >= 1 && quantity <= 1000)
                Text('Gesamt: ${euro(quantity * sale.priceCents)}',
                  key: const Key('reservation-total'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              if (sale != null) Padding(padding: const EdgeInsets.only(top: 8),
                child: Text('Zahlungsfrist: ${sale.reservationDays} Tage ab Reservierung. Die genaue Frist legt das Backend fest.')),
              const SizedBox(height: 12),
              ExpansionTile(initiallyExpanded: session.api.orgToken.isEmpty,
                title: const Text('Lokaler Demo-Zugang'),
                childrenPadding: const EdgeInsets.only(bottom: 16), children: [
                  const Text('Den Zugang aus backend/data/org-token einmal einfügen. Er bleibt nur für diesen App-Lauf gespeichert.'),
                  const SizedBox(height: 12),
                  TextFormField(key: const Key('org-token'), controller: _token,
                    obscureText: true, enableSuggestions: false, autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Demo-Token', border: OutlineInputBorder()),
                    validator: (value) => (value?.trim().isEmpty ?? true) ? 'Bitte den lokalen Demo-Token einfügen.' : null),
                ]),
              if (session.error != null) _notice(session.error!),
              if (session.pending != null && !session.submitting) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                child: SelectableText('Antwort unklar. Name und Anzahl bleiben gesperrt. Erneutes Senden verwendet dieselbe Anfrage und erzeugt keine zweite Reservierung.\nAnfragereferenz: ${session.pending!.requestId}')),
              const SizedBox(height: 12),
              FilledButton.icon(key: const Key('reserve-tickets'),
                onPressed: session.submitting || _refreshing || _loading ? null : _submit,
                icon: session.submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.confirmation_number_outlined),
                label: Text(session.submitting ? 'Reservierung wird gespeichert …'
                  : session.pending != null ? 'Dieselbe Anfrage erneut senden' : 'Verbindlich reservieren (Demo)')),
              const SizedBox(height: 10),
              const Text('Die Reservierung hält Karten frei. Als Einnahme zählen sie erst nach bestätigtem Zahlungseingang.',
                style: TextStyle(fontSize: 12, color: Color(0xFF617079))),
            ],
          )),
          const SizedBox(height: 24),
        ]),
      )),
    );
  }

  Widget _notice(String text) => Padding(padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(text, style: const TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.w600)));

  Widget _confirmation(Reservation value) => Card(color: accent, child: Padding(
    padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.check_circle_outline, size: 36),
      const SizedBox(height: 12),
      const Text('Reservierung gespeichert', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      Text(value.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      Text('${value.quantity} Karten · ${euro(value.totalCents)}'),
      Text(value.statusLabel),
      const SizedBox(height: 12),
      const Text('Reservierungsnummer'),
      SelectableText(value.reference),
      const SizedBox(height: 12),
      Text('Zahlungsfrist: ${reservationDeadline(value.expiresAt)}'),
      const SizedBox(height: 16),
      const Text('Noch keine Eintrittskarte. PDF, QR und Zahlungsinformationen folgen im nächsten Ausbauschritt.'),
      const SizedBox(height: 10),
      OutlinedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ReservationSummary(reservation: value))),
        child: const Text('Reservierungsdaten öffnen')),
    ]),
  ));
}

/// Uses only the saved server response; PDF/payment details follow in SDA-12.
class ReservationSummary extends StatelessWidget {
  const ReservationSummary({super.key, required this.reservation});
  final Reservation reservation;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reservierungsübersicht')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const Text('DEMO · NOCH KEINE EINTRITTSKARTE', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      Text(reservation.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      Text('${reservation.quantity} Karten zu je ${euro(reservation.priceCents)}'),
      Text('Gesamt: ${euro(reservation.totalCents)}'),
      const SizedBox(height: 18),
      SelectableText('Referenz: ${reservation.reference}'),
      Text('Frist: ${reservationDeadline(reservation.expiresAt)}'),
      Text('Status: ${reservation.statusLabel}'),
      const SizedBox(height: 18),
      const Text('Zahlungsdaten, PDF und QR folgen in SDA-12. Hier werden ausschließlich gespeicherte Reservierungsdaten angezeigt.'),
    ]),
  );
}
