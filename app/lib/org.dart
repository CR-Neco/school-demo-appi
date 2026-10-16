import 'package:flutter/foundation.dart';

import 'tickets.dart';

enum OrgAction { payment, extend, cancel }

class OrgChange {
  OrgChange(this.action) : requestId = newReservationRequestId();
  final OrgAction action;
  final String requestId;
  int get days => 3;
  String get label => switch (action) {
    OrgAction.payment => 'Zahlung bestätigen',
    OrgAction.extend => 'Um 3 Tage verlängern',
    OrgAction.cancel => 'Reservierung stornieren',
  };
}

/// Keeps unresolved changes alive while navigating between org details and list.
class OrgSession {
  OrgSession(this.tickets);
  final TicketSession tickets;
  TicketApi get api => tickets.api;
  final Map<String, ReservationAdmin> _details = {};
  ReservationAdmin detail(String reference) => _details.putIfAbsent(reference,
    () => ReservationAdmin(api, reference, onSaved: tickets.updateReservation));
  void dispose() {
    for (final detail in _details.values) { detail.dispose(); }
  }
}

class ReservationAdmin extends ChangeNotifier {
  ReservationAdmin(this.api, this.reference, {this.onSaved});
  final TicketApi api;
  final String reference;
  final void Function(Reservation)? onSaved;
  Reservation? current;
  OrgChange? pending;
  String? loadError, changeError, notice;
  bool loading = false, working = false, requiresReload = false;
  bool _disposed = false, _unclear = false;
  bool get busy => loading || working;
  bool get canChange => current?.isOpen == true && !busy && pending == null && !requiresReload && loadError == null;

  void _notify() { if (!_disposed) notifyListeners(); }

  Future<void> load() async {
    if (busy) return;
    loading = true;
    loadError = null;
    notice = null;
    _notify();
    try {
      current = await api.loadReservation(reference);
      requiresReload = false;
      if (!_disposed) onSaved?.call(current!);
    } catch (error) {
      loadError = error is TicketFailure ? error.message : 'Reservierung konnte nicht geladen werden.';
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> change(OrgAction action) async {
    if (!canChange) return;
    pending = OrgChange(action);
    await retry();
  }

  Future<void> retry() async {
    final change = pending;
    if (change == null || busy) return;
    working = true;
    changeError = null;
    notice = null;
    _notify();
    try {
      final response = switch (change.action) {
        OrgAction.payment => api.confirmPayment(reference),
        OrgAction.cancel => api.cancelReservation(reference),
        OrgAction.extend => api.extendReservation(reference, days: change.days, requestId: change.requestId),
      };
      final result = await response;
      current = result;
      pending = null;
      _unclear = false;
      requiresReload = false;
      loadError = null;
      notice = 'Änderung im Backend bestätigt.';
      if (!_disposed) onSaved?.call(result);
    } catch (error) {
      changeError = error is TicketFailure ? error.message : 'Antwort unklar. Bitte dieselbe Änderung erneut senden.';
      _unclear = _unclear || error is! TicketFailure || error.outcomeUnknown;
      if (!_unclear) {
        pending = null;
        requiresReload = true;
      }
    } finally {
      working = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
