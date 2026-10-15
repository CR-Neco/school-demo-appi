import 'package:flutter/material.dart';
import '../fundraising.dart';
import 'components.dart';

class FundraisingCard extends StatelessWidget {
  const FundraisingCard({super.key, required this.year, required this.data,
    required this.loading, required this.error, required this.onRefresh});
  final int year;
  final Fundraising? data;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final totals = data;
    return Container(
      key: const Key('fundraising-card'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(26)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('UNSERE ABIKASSE', style: TextStyle(color: accent, fontSize: 11, letterSpacing: 1.5)),
            const SizedBox(height: 6),
            Text('Fundraising Abi $year', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          ])),
          IconButton(onPressed: loading ? null : onRefresh, tooltip: 'Finanzierungsstand aktualisieren',
            icon: const Icon(Icons.refresh_rounded), color: accent, disabledColor: Colors.white38),
        ]),
        const SizedBox(height: 16),
        if (loading) ...[
          const Text('Finanzierungsstand wird geladen …', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          const LinearProgressIndicator(color: accent, backgroundColor: Colors.white12),
        ] else if (error != null || totals == null) ...[
          const Text('Finanzierungsstand nicht verfügbar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(error ?? 'Bitte Finanzierungsstand laden.', style: const TextStyle(color: Colors.white70)),
          TextButton(onPressed: onRefresh, style: TextButton.styleFrom(foregroundColor: accent),
            child: const Text('Erneut versuchen')),
        ] else ...[
          Text(euro(totals.raisedCents), key: const Key('raised-amount'),
            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(totals.hasTarget ? 'von ${euro(totals.targetCents)} Ziel' : 'Ziel noch nicht festgelegt',
            style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 18),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
            key: const Key('fundraising-progress'), value: totals.barValue, minHeight: 10,
            color: accent, backgroundColor: Colors.white12,
            semanticsLabel: 'Finanzierungsfortschritt',
          )),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 8, children: [
            if (totals.hasTarget) Text('${percentLabel(totals.percent!)} erreicht', style: const TextStyle(color: accent, fontWeight: FontWeight.bold)),
            if (totals.hasTarget) Text(totals.raisedCents >= totals.targetCents
                ? 'Ziel erreicht!'
                : 'Noch ${euro(totals.remainingCents)} bis zum Ball',
              style: const TextStyle(color: Colors.white70)),
          ]),
          const SizedBox(height: 16),
          const Text('Bestätigte Einnahmen abzüglich Ausgaben. Offene Reservierungen zählen noch nicht.',
            style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4)),
        ],
      ]),
    );
  }
}
