import 'package:appi/tickets.dart';

Reservation sample({String reference = 'ABI-ORG-123', String status = 'reserved', bool overdue = false, DateTime? deadline}) => Reservation(
  reference: reference, eventId: 'abi-ball', name: 'Lina Beispiel', quantity: 2,
  priceCents: 4500, totalCents: 9000, status: status,
  expiresAt: deadline ?? DateTime.utc(2027, 6, 1, 18), overdue: overdue);

