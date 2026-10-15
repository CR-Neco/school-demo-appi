"""Small, explicit SQL persistence layer for the local demo."""
import sqlite3
from contextlib import contextmanager
from pathlib import Path

SCHEMA = """
CREATE TABLE IF NOT EXISTS config (
 id INTEGER PRIMARY KEY CHECK(id=1), school TEXT NOT NULL, year INTEGER NOT NULL,
 target_cents INTEGER NOT NULL CHECK(target_cents>0),
 reservation_days INTEGER NOT NULL CHECK(reservation_days>0));
CREATE TABLE IF NOT EXISTS actions (
 id TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS events (
 id TEXT PRIMARY KEY, title TEXT NOT NULL, capacity INTEGER NOT NULL CHECK(capacity>=0),
 price_cents INTEGER NOT NULL CHECK(price_cents>=0));
CREATE TABLE IF NOT EXISTS reservations (
 id TEXT PRIMARY KEY, request_id TEXT NOT NULL UNIQUE,
 event_id TEXT NOT NULL REFERENCES events(id), name TEXT NOT NULL,
 quantity INTEGER NOT NULL CHECK(quantity>0), price_cents INTEGER NOT NULL CHECK(price_cents>=0),
 status TEXT NOT NULL CHECK(status IN ('reserved','paid','cancelled')),
 created_at TEXT NOT NULL, expires_at TEXT NOT NULL, paid_at TEXT);
CREATE TABLE IF NOT EXISTS ledger (
 id INTEGER PRIMARY KEY, reservation_id TEXT UNIQUE REFERENCES reservations(id),
 action_id TEXT REFERENCES actions(id), amount_cents INTEGER NOT NULL,
 description TEXT NOT NULL);
PRAGMA user_version=1;
"""

class Database:
    def __init__(self, path: str):
        self.path = str(Path(path).expanduser().resolve())

    @contextmanager
    def connect(self, write=False):
        db = sqlite3.connect(self.path, timeout=10, isolation_level=None)
        db.row_factory = sqlite3.Row
        db.execute('PRAGMA foreign_keys=ON')
        try:
            db.execute('BEGIN IMMEDIATE' if write else 'BEGIN')
            yield db
            db.commit()
        except BaseException:
            db.rollback()
            raise
        finally:
            db.close()

    def initialize(self):
        Path(self.path).parent.mkdir(parents=True, exist_ok=True)
        with sqlite3.connect(self.path) as db:
            version = db.execute('PRAGMA user_version').fetchone()[0]
            if version not in (0, 1):
                raise RuntimeError('Unsupported database schema version')
            db.executescript(SCHEMA)
            # Minimal bootstrap; richer reproducible scenarios and reset follow SDA-8.
            db.execute("INSERT OR IGNORE INTO config VALUES (1, ?, 2027, 1500000, 5)",
                       ('Philipp Melanchthon Gymnasium Meine',))
            db.execute("INSERT OR IGNORE INTO events VALUES ('abi-ball', 'Abiball 2027 (Demo)', 300, 4500)")
            db.executemany('INSERT OR IGNORE INTO actions VALUES (?, ?, ?)', [
                ('kiosk', 'Schulkiosk', 'Demo: Mensa, Montag bis Donnerstag'),
                ('schulfest', 'Verkaufsstand Schulfest', 'Fiktive Verkaufsaktion'),
                ('leseabend', 'Verkaufsstand Leseabend', 'Fiktive Verkaufsaktion'),
                ('sportfest', 'Verkaufsstand Sportfest', 'Fiktive Verkaufsaktion')])
