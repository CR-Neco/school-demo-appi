import 'package:flutter/material.dart';

import '../api.dart';
import '../config.dart';
import '../fundraising.dart';
import '../widgets/fundraising_card.dart';
import '../widgets/components.dart';
import '../widgets/school_artwork.dart';
import 'detail.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.config,
    required this.error,
    required this.loading,
    required this.onRetry,
    required this.dashboard,
    required this.dashboardError,
    required this.dashboardLoading,
    required this.onRefreshDashboard,
  });
  final SchoolConfig? config;
  final String? error;
  final bool loading;
  final VoidCallback onRetry;
  final Fundraising? dashboard;
  final String? dashboardError;
  final bool dashboardLoading;
  final Future<void> Function() onRefreshDashboard;

  @override
  Widget build(BuildContext context) {
    final year = config?.year ?? AppConfig.year;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    Text(
                      AppConfig.name,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const InfoChip('SIMULATOR-DEMO'),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  config?.school ?? AppConfig.school,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF617079),
                  ),
                ),
                Text('Abiturjahrgang $year', style: const TextStyle(fontSize: 12, color: Color(0xFF617079))),
              const SizedBox(height: 10),
                const Text(
                  'Das Beste kommt\nzum Abschluss.',
                  style: TextStyle(
                    fontSize: 34,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  AppConfig.tagline,
                  style: TextStyle(fontSize: 16, color: Color(0xFF617079)),
                ),
                const SizedBox(height: 22),
                FundraisingCard(year: year, data: dashboard,
                  loading: dashboardLoading, error: dashboardError,
                  onRefresh: onRefreshDashboard),
                const SizedBox(height: 18),
                SizedBox(
                  height: 145,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const SchoolArtwork(),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: ink,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Gemeinsam Richtung Abiball',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const Positioned(
                          right: 10,
                          top: 10,
                          child: InfoChip('Symbolbild'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (loading) const LinearProgressIndicator(minHeight: 2),
                if (error != null)
                  Card(
                    color: const Color(0xFFFFE8D9),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Schuldaten nicht verfügbar',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(error!),
                          TextButton.icon(
                            onPressed: loading ? null : onRetry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Erneut versuchen'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (config != null && error == null && dashboard != null && dashboardError == null && !dashboardLoading)
                  const Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Color(0xFF487552),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Lokales Backend verbunden',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                const SizedBox(height: 22),
                const Text(
                  'Euer Jahrgang organisiert.',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 320 ? 1 : 2;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 14) / columns;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (final section in _sections)
                          SizedBox(
                            width: width,
                            child: SectionCard(
                              title: section.title,
                              subtitle: section.subtitle,
                              icon: section.icon,
                              color: section.color,
                              onTap: () async {
                                await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SectionDetail(
                                    title: section.title,
                                    icon: section.icon,
                                    description: section.description,
                                    chips: section.chips,
                                    items: section.items,
                                  ),
                                ),
                              );
                                await onRefreshDashboard();
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Für euren Jahrgang gemacht. Von euren Ideen weitergedacht.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF617079)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section {
  const _Section(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.description,
    this.chips,
    this.items,
  );
  final String title, subtitle, description;
  final IconData icon;
  final Color color;
  final List<String> chips;
  final List<(String, String)> items;
}

const _sections = [
  _Section(
    'Kiosk',
    'Kleine Pause. Großer Beitrag.',
    Icons.storefront_rounded,
    Color(0xFFDDF49C),
    'Euer Treffpunkt in der Mensa. Hier entsteht später Platz für Angebot, Schichten und Tagesabrechnung.',
    ['Mo–Do', 'Mensa'],
    [
      (
        'Beispielangebot',
        'Kaffee 1,50 € · Brezel 1,20 € · Wasser 1,00 €. Fiktive Preise.',
      ),
      (
        'Wie geht es weiter?',
        'Welche Information würde euch die Kiosk-Schicht erleichtern?',
      ),
    ],
  ),
  _Section(
    'Verkaufsstände',
    'Gemeinsam etwas auf die Beine stellen.',
    Icons.festival_rounded,
    Color(0xFFF9D8B9),
    'Schulfest, Leseabend oder Sportfest: Jede Aktion kann eure Abikasse voranbringen.',
    ['3 Demo-Aktionen', 'Teamwork'],
    [
      ('Schulfest', 'Beispiel: Kuchen und Getränke verkaufen.'),
      ('Leseabend', 'Beispiel: Snacks für die Pause vorbereiten.'),
      ('Sportfest', 'Beispiel: Erfrischungen am Spielfeldrand anbieten.'),
    ],
  ),
  _Section(
    'Abiball-Tickets',
    'Von der Reservierung zum großen Abend.',
    Icons.confirmation_number_outlined,
    Color(0xFFD5DEF6),
    'Hier folgt der zentrale Kartenworkflow: reservieren, Beleg übergeben und nach Kontoprüfung die Zahlung bestätigen.',
    ['In Vorbereitung', 'Keine echten Buchungen'],
    [
      (
        'Unser Demo-Workflow',
        'Reservierung → Zahlungsinformationen → Zahlungseingang bestätigen → bestätigte Karten.',
      ),
      (
        'Was hier noch fehlt',
        'Reservierungsformular, Beleg und Org-Verwaltung folgen in den nächsten Tickets.',
      ),
    ],
  ),
  _Section(
    'Org-Team',
    'Kurze Wege. Klare Zuständigkeiten.',
    Icons.groups_outlined,
    Color(0xFFE7DAF2),
    'Ein gemeinsamer Anlaufpunkt für euren Jahrgang. Alle Namen sind fiktive Beispiele.',
    ['Kontakt', 'Organisation'],
    [
      ('Kiosk & Verkaufsstände', 'Alex Beispiel · Organisation der Aktionen.'),
      (
        'Karten & Abikasse',
        'Sam Beispiel · Ansprechpartner für Reservierungen und Zahlungen.',
      ),
    ],
  ),
];
