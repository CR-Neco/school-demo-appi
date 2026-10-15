from datetime import datetime, timedelta, timezone
from uuid import uuid4

class DomainError(Exception):
    def __init__(self, status, code, message):
        self.status, self.code, self.message = status, code, message

def now():
    return datetime.now(timezone.utc)

def get_event(db, event_id):
    row = db.execute('SELECT * FROM events WHERE id=?', (event_id,)).fetchone()
    if not row:
        raise DomainError(404, 'event_not_found', 'Veranstaltung nicht gefunden.')
    return dict(row)

def availability(db, event_id):
    event = get_event(db, event_id)
    totals = dict(db.execute(
        'SELECT status, SUM(quantity) FROM reservations WHERE event_id=? GROUP BY status',
        (event_id,)).fetchall())
    reserved, paid = totals.get('reserved', 0), totals.get('paid', 0)
    return dict(event_id=event_id, capacity=event['capacity'], reserved=reserved,
                paid=paid, available=event['capacity']-reserved-paid)

def get_reservation(db, ref):
    row = db.execute('SELECT * FROM reservations WHERE id=?', (ref,)).fetchone()
    if not row:
        raise DomainError(404, 'reservation_not_found', 'Reservierung nicht gefunden.')
    return dict(row)

def present(row):
    result = {k: v for k, v in row.items() if k != 'request_id'}
    result['total_cents'] = row['quantity'] * row['price_cents']
    result['overdue'] = row['status'] == 'reserved' and datetime.fromisoformat(row['expires_at']) < now()
    return result

def reserve(db, data):
    request_id = str(data.request_id)
    existing = db.execute('SELECT * FROM reservations WHERE request_id=?', (request_id,)).fetchone()
    if existing:
        row = dict(existing)
        if (row['event_id'], row['name'], row['quantity']) != (data.event_id, data.name, data.quantity):
            raise DomainError(409, 'request_conflict', 'Anfragereferenz bereits anders verwendet.')
        return present(row)
    event = get_event(db, data.event_id)
    if availability(db, data.event_id)['available'] < data.quantity:
        raise DomainError(409, 'insufficient_capacity', 'Nicht genügend Karten verfügbar.')
    timestamp = now()
    days = db.execute('SELECT reservation_days FROM config WHERE id=1').fetchone()[0]
    ref = 'ABI-' + uuid4().hex.upper()
    db.execute('INSERT INTO reservations VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
               (ref, request_id, data.event_id, data.name, data.quantity, event['price_cents'],
                'reserved', timestamp.isoformat(), (timestamp+timedelta(days=days)).isoformat(), None))
    return present(get_reservation(db, ref))

def confirm_payment(db, ref):
    row = get_reservation(db, ref)
    if row['status'] == 'cancelled':
        raise DomainError(409, 'invalid_state', 'Stornierte Reservierung kann nicht bezahlt werden.')
    if row['status'] == 'reserved':
        db.execute("UPDATE reservations SET status='paid', paid_at=? WHERE id=?", (now().isoformat(), ref))
        db.execute('INSERT INTO ledger (reservation_id, amount_cents, description) VALUES (?, ?, ?)',
                   (ref, row['quantity']*row['price_cents'], 'Bestätigter Demo-Zahlungseingang'))
    return present(get_reservation(db, ref))

def cancel(db, ref):
    row = get_reservation(db, ref)
    if row['status'] == 'paid':
        raise DomainError(409, 'invalid_state', 'Bezahlte Buchungen können in Demo 1 nicht storniert werden.')
    db.execute("UPDATE reservations SET status='cancelled' WHERE id=?", (ref,))
    return present(get_reservation(db, ref))

def extend(db, ref, days):
    row = get_reservation(db, ref)
    if row['status'] != 'reserved':
        raise DomainError(409, 'invalid_state', 'Nur offene Reservierungen können verlängert werden.')
    base = max(now(), datetime.fromisoformat(row['expires_at']))
    db.execute('UPDATE reservations SET expires_at=? WHERE id=?', ((base+timedelta(days=days)).isoformat(), ref))
    return present(get_reservation(db, ref))
