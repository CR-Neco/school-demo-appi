import 'package:flutter/material.dart';

import '../demo_content.dart';
import '../fundraising.dart';
import '../tickets.dart';
import '../widgets/action_artwork.dart';
import '../widgets/components.dart';

class DemoSectionsScreen extends StatefulWidget {
  const DemoSectionsScreen({super.key, required this.api, required this.kiosk});
  final DemoContentApi api;
  final bool kiosk;
  @override
  State<DemoSectionsScreen> createState() => _DemoSectionsScreenState();
}

class _DemoSectionsScreenState extends State<DemoSectionsScreen> {
  DemoContent? _content;
  String? _error;
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _content = null; _error = null; });
    try {
      final content = await widget.api.loadDemoContent();
      if (mounted) setState(() { _content = content; });
    } catch (error) {
      if (mounted) setState(() { _error = error is TicketFailure ? error.message : 'Demo-Inhalte konnten nicht geladen werden.'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }
  @override
  Widget build(BuildContext context) {
    final content = _content;
    return Scaffold(
      appBar: AppBar(title: Text(widget.kiosk ? 'Kiosk' : 'Verkaufsstände'), actions: [
        IconButton(onPressed: _loading ? null : _load, tooltip: 'Demo-Inhalte aktualisieren', icon: const Icon(Icons.refresh)),
      ]),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: ListView(
        padding: const EdgeInsets.all(22), children: [
          const Wrap(spacing: 8, children: [InfoChip('FIKTIVE DEMO'), InfoChip('Ideen willkommen')]),
          const SizedBox(height: 14),
          const Text('Beispielangebote und -termine für unseren Jahrgang. Die Beträge stammen aus der aktuellen Demo-Abikasse.'),
          const SizedBox(height: 18),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Erneut versuchen')),
          ],
          if (content != null) ...[
            if (widget.kiosk) ..._kiosk(content.kiosk)
            else for (final action in content.actions) _action(action),
            const SizedBox(height: 18),
            ExpandableInfo(title: 'Euer Demo-Org-Team',
              body: content.contacts.map((contact) => '${contact.name} · ${contact.role}').join('\n')),
          ],
          const SizedBox(height: 24),
        ],
      ))),
    );
  }

  List<Widget> _kiosk(DemoKiosk kiosk) => [
    const SizedBox(height: 160, child: ActionArtwork('kiosk')),
    const SizedBox(height: 18),
    Text(kiosk.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
    const SizedBox(height: 8),
    Text(kiosk.description),
    const SizedBox(height: 10),
    Wrap(spacing: 8, children: [InfoChip(kiosk.opening), InfoChip(kiosk.location)]),
    const SizedBox(height: 16),
    FinanceBreakdown(kiosk.finance),
    const SizedBox(height: 20),
    const Text('Was darf es sein?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
    const SizedBox(height: 10),
    for (final product in kiosk.products) Card(child: Padding(padding: const EdgeInsets.all(16), child: Wrap(
      alignment: WrapAlignment.spaceBetween, spacing: 16, runSpacing: 8, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(product.description),
        ]),
        Text(euro(product.priceCents), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ],
    ))),
    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Fiktive Preise · Verkauf findet vor Ort statt.')),
    for (final note in kiosk.notes) ExpandableInfo(title: note.title, body: note.body),
  ];

  Widget _action(DemoAction action) => Card(margin: const EdgeInsets.only(bottom: 20), child: Padding(
    padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(height: 135, child: ActionArtwork(action.artwork)),
      const SizedBox(height: 16),
      Text(action.title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text('${action.dateLabel}\n${action.location}', style: const TextStyle(color: Color(0xFF617079))),
      const SizedBox(height: 10),
      Text(action.description),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 4, children: action.chips.map(InfoChip.new).toList()),
      const SizedBox(height: 12),
      FinanceBreakdown(action.finance),
      const SizedBox(height: 10),
      ExpandableInfo(title: 'Was brauchen wir dafür?', body: action.idea),
    ]),
  ));
}

class FinanceBreakdown extends StatelessWidget {
  const FinanceBreakdown(this.finance, {super.key});
  final DemoFinance finance;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('BEITRAG ZUR ABIKASSE', style: TextStyle(color: accent, fontSize: 11, letterSpacing: 1)),
      const SizedBox(height: 5),
      Text(euro(finance.raisedCents), style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text('Einnahmen ${euro(finance.incomeCents)} · Ausgaben ${euro(finance.expensesCents)}', style: const TextStyle(color: Colors.white70)),
    ]),
  );
}
