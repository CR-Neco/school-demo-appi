/// Authoritative ledger totals from the backend, always in integer cents.
class Fundraising {
  const Fundraising({required this.targetCents, required this.raisedCents});
  final int targetCents;
  final int raisedCents;

  factory Fundraising.fromJson(Map<String, dynamic> json) {
    final target = json['target_cents'];
    final raised = json['raised_cents'];
    if (target is! int || raised is! int) {
      throw const FormatException('Invalid fundraising totals');
    }
    return Fundraising(targetCents: target, raisedCents: raised);
  }

  bool get hasTarget => targetCents > 0;
  double? get percent => hasTarget ? raisedCents / targetCents * 100 : null;
  double get barValue => hasTarget
      ? (raisedCents / targetCents).clamp(0.0, 1.0).toDouble()
      : 0.0;
  int get remainingCents => !hasTarget || raisedCents >= targetCents
      ? 0
      : targetCents - raisedCents;
}

/// German EUR display without a runtime localization/network dependency.
String euro(int cents) {
  final absolute = cents.abs();
  final euros = (absolute ~/ 100).toString();
  final grouped = euros.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.',
  );
  return '${cents < 0 ? '−' : ''}$grouped,${(absolute % 100).toString().padLeft(2, '0')} €';
}

String percentLabel(double percent) =>
    '${percent.toStringAsFixed(1).replaceAll('.', ',')} %';
