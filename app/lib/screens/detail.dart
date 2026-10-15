import 'package:flutter/material.dart';

import '../widgets/components.dart';

class SectionDetail extends StatelessWidget {
  const SectionDetail({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
    required this.chips,
    required this.items,
  });
  final String title, description;
  final IconData icon;
  final List<String> chips;
  final List<(String, String)> items;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: CircleAvatar(
            radius: 32,
            backgroundColor: accent,
            child: Icon(icon, size: 32, color: ink),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(description, style: const TextStyle(fontSize: 16, height: 1.5)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, children: chips.map(InfoChip.new).toList()),
        const SizedBox(height: 24),
        for (final item in items) ExpandableInfo(title: item.$1, body: item.$2),
        const SizedBox(height: 24),
        const Text(
          'Demo-Inhalte · Funktionen werden schrittweise ergänzt.',
          style: TextStyle(color: Color(0xFF617079), fontSize: 12),
        ),
      ],
    ),
  );
}
