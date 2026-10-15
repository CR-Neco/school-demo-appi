import 'package:flutter/material.dart';

const ink = Color(0xFF172D37);
const accent = Color(0xFFDDF49C);

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: ink),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF617079), fontSize: 13),
            ),
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(Icons.arrow_forward_rounded, size: 21),
            ),
          ],
        ),
      ),
    ),
  );
}

class InfoChip extends StatelessWidget {
  const InfoChip(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Chip(
    label: Text(label),
    visualDensity: VisualDensity.compact,
    backgroundColor: const Color(0xFFEDF0E8),
    side: BorderSide.none,
    labelStyle: const TextStyle(fontSize: 12, color: ink),
  );
}

class ExpandableInfo extends StatelessWidget {
  const ExpandableInfo({super.key, required this.title, required this.body});
  final String title, body;
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(title),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      children: [Align(alignment: Alignment.centerLeft, child: Text(body))],
    ),
  );
}
