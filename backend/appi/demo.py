"""Explicit local development reset. Never exposed through HTTP."""
import argparse
from copy import deepcopy
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import socket
import sqlite3
from uuid import NAMESPACE_URL, uuid5

from .db import Database

DEFAULT_DB = Path(__file__).resolve().parents[1] / 'data' / 'appi.sqlite3'


def fixture():
    return json.loads(Path(__file__).with_name('demo_data.json').read_text(encoding='utf-8'))


def catalog(db):
    data = fixture()
    result = {'is_demo': True, 'kiosk': deepcopy(data['kiosk']),
              'actions': deepcopy(data['actions']), 'contacts': data['contacts']}
    for item in [result['kiosk'], *result['actions']]:
        sums = db.execute('''SELECT COALESCE(SUM(CASE WHEN amount_cents>0 THEN amount_cents ELSE 0 END),0),
            COALESCE(SUM(CASE WHEN amount_cents<0 THEN -amount_cents ELSE 0 END),0)
            FROM ledger WHERE action_id=?''', (item['id'],)).fetchone()
        item['income_cents'], item['expenses_cents'] = sums[0], sums[1]
        item['raised_cents'] = sums[0] - sums[1]
        item.pop('seed_income_cents')
        item.pop('seed_expenses_cents')
    return result


def ensure_backend_stopped(port=8000):
    try:
        connection = socket.create_connection(('127.0.0.1', port), timeout=0.5)
    except ConnectionRefusedError:
        return
    except OSError as error:
        raise ValueError(f'Backend-Status auf Port {port} unklar. Bitte Backend stoppen und erneut versuchen.') from error
    else:
        connection.close()
        raise ValueError(f'Port {port} ist belegt. Bitte das Backend zuerst mit Ctrl+C stoppen.')


def reset_database(path, *, scenario='demo', at=None, overrides=None):
    """Internal helper. The CLI checks explicit intent and stopped backend first."""
    if scenario not in {'demo', 'empty'}:
        raise ValueError('Unbekannter Ausgangszustand.')
    data = fixture()
    config = data['config'] | (overrides or {})
    valid = (isinstance(config['school'], str) and bool(config['school'].strip())
             and 2000 <= config['year'] <= 2100 and config['target_cents'] > 0
             and config['ticket_price_cents'] >= 0 and 1 <= config['reservation_days'] <= 30)
    held = sum(item['quantity'] for item in data['reservations'] if item['status'] != 'cancelled')
    if not valid or config['capacity'] < (held if scenario == 'demo' else 0):
        raise ValueError('Konfiguration ungültig. Demo-Kontingent muss mindestens 7 Karten betragen.')
    instant = at or datetime.now(timezone.utc)
    if instant.tzinfo is None:
        raise ValueError('Demo-Zeit benötigt eine Zeitzone, z.B. +00:00.')
    instant = instant.astimezone(timezone.utc)
    path = Path(path).expanduser().resolve()
    backup = None
    if path.exists():
        backup_dir = path.parent / 'backups'
        backup_dir.mkdir(parents=True, exist_ok=True)
        backup = backup_dir / f'{path.stem}-{datetime.now(timezone.utc):%Y%m%dT%H%M%S%fZ}.sqlite3'
        with sqlite3.connect(path) as source, sqlite3.connect(backup) as target:
            source.backup(target)
    database = Database(str(path))
    database.initialize()
    with database.connect(write=True) as db:
        for table in ['reservation_extensions', 'ledger', 'reservations', 'actions', 'events']:
            db.execute(f'DELETE FROM {table}')
        db.execute('''UPDATE config SET school=?, year=?, target_cents=?, reservation_days=? WHERE id=1''',
                   (config['school'].strip(), config['year'], config['target_cents'], config['reservation_days']))
        db.execute('INSERT INTO events VALUES (?, ?, ?, ?)',
                   ('abi-ball', f"Abiball {config['year']} (Demo)", config['capacity'], config['ticket_price_cents']))
        for item in [data['kiosk'], *data['actions']]:
            db.execute('INSERT INTO actions VALUES (?, ?, ?)', (item['id'], item['title'], item['description']))
            if scenario == 'demo':
                db.execute('INSERT INTO ledger (action_id, amount_cents, description) VALUES (?, ?, ?)',
                           (item['id'], item['seed_income_cents'], 'Fiktive Demo-Einnahmen'))
                db.execute('INSERT INTO ledger (action_id, amount_cents, description) VALUES (?, ?, ?)',
                           (item['id'], -item['seed_expenses_cents'], 'Fiktive Demo-Ausgaben'))
        if scenario == 'demo':
            for item in data['reservations']:
                created = instant + timedelta(days=item['created_days'])
                # Open/paid/cancelled deadlines honor the configured reservation duration.
                expires = created + timedelta(days=config['reservation_days'])
                if item['status'] == 'reserved' and item['expires_days'] > 0:
                    expires = instant + timedelta(days=max(1, config['reservation_days'] + item['created_days']))
                    created = expires - timedelta(days=config['reservation_days'])
                if item['expires_days'] < 0:
                    expires = instant + timedelta(days=item['expires_days'])
                    created = expires - timedelta(days=config['reservation_days'])
                paid = (instant - timedelta(days=1)).isoformat() if item['status'] == 'paid' else None
                db.execute('INSERT INTO reservations VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                           (item['id'], str(uuid5(NAMESPACE_URL, 'appi-demo:' + item['id'])), 'abi-ball',
                            item['name'], item['quantity'], config['ticket_price_cents'], item['status'],
                            created.isoformat(), expires.isoformat(), paid))
                if item['status'] == 'paid':
                    db.execute('INSERT INTO ledger (reservation_id, amount_cents, description) VALUES (?, ?, ?)',
                               (item['id'], item['quantity'] * config['ticket_price_cents'], 'Fiktive Demo-Ticketzahlung'))
    return backup


def main(argv=None):
    parser = argparse.ArgumentParser(description='PMG AppI lokal auf einen definierten Demo-Stand zurücksetzen.')
    parser.add_argument('command', choices=['reset'])
    parser.add_argument('--confirm', help='Zum bewussten Zurücksetzen exakt RESET angeben.')
    parser.add_argument('--scenario', choices=['demo', 'empty'], default='demo')
    parser.add_argument('--db', default=os.environ.get('APPI_DB_PATH', str(DEFAULT_DB)))
    parser.add_argument('--port', type=int, default=8000)
    parser.add_argument('--at', help='Optionaler Referenzzeitpunkt als ISO-8601 mit Zeitzone.')
    for flag in ['year', 'target-cents', 'ticket-price-cents', 'capacity', 'reservation-days']:
        parser.add_argument('--' + flag, type=int)
    parser.add_argument('--school')
    args = parser.parse_args(argv)
    if args.confirm != 'RESET':
        parser.error('Kein Reset ausgeführt. Bitte --confirm RESET bewusst angeben.')
    try:
        if not 1 <= args.port <= 65535:
            raise ValueError('Port muss zwischen 1 und 65535 liegen.')
        ensure_backend_stopped(args.port)
        overrides = {key: getattr(args, key) for key in fixture()['config'] if getattr(args, key, None) is not None}
        backup = reset_database(args.db, scenario=args.scenario,
                                at=datetime.fromisoformat(args.at) if args.at else None, overrides=overrides)
    except (ValueError, OSError, sqlite3.Error, RuntimeError) as error:
        parser.exit(1, f'Reset nicht abgeschlossen: {error}\n')
    database = Database(args.db)
    with database.connect() as db:
        from .service import availability
        stock = availability(db, 'abi-ball')
        raised = db.execute('SELECT COALESCE(SUM(amount_cents), 0) FROM ledger').fetchone()[0]
    whole, cents = divmod(raised, 100)
    print(f'Ausgangszustand {args.scenario!r} vorbereitet. Backend und App neu starten.')
    print(f'Datenbank: {database.path}')
    amount = f'{whole:,}'.replace(',', '.') + f',{cents:02d}'
    print(f'Gespeicherter Stand: {amount} EUR Abikasse')
    print(f"Karten: {stock['available']} verfügbar | {stock['reserved']} reserviert | {stock['paid']} bezahlt")
    if backup:
        print(f'Sicherung: {backup}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
