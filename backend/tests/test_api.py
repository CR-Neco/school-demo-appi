"""Ausführen ausschließlich lokal über VS Code; nicht durch die Live-KI."""
from concurrent.futures import ThreadPoolExecutor
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from appi.main import create_app

HEADERS = {'Authorization': 'Bearer local-test-token'}

@pytest.fixture
def client(tmp_path):
    with TestClient(create_app(str(tmp_path / 'test.sqlite3'), 'local-test-token')) as c:
        yield c

def order(client, quantity=2, request_id=None):
    return client.post('/api/v1/reservations', headers=HEADERS, json={
        'name': 'Demo Beispiel', 'event_id': 'abi-ball',
        'quantity': quantity, 'request_id': request_id or str(uuid4())})

def test_payment_is_idempotent_and_does_not_reduce_capacity_twice(client):
    reservation = order(client).json()
    assert reservation['total_cents'] == 9000
    assert client.get('/api/v1/dashboard').json()['raised_cents'] == 0
    before = client.get('/api/v1/events/abi-ball/availability').json()
    for _ in range(2):
        response = client.post(f"/api/v1/reservations/{reservation['id']}/payment", headers=HEADERS)
        assert response.status_code == 200
        assert response.json()['status'] == 'paid'
    after = client.get('/api/v1/events/abi-ball/availability').json()
    assert after['available'] == before['available'] == 298
    assert after['reserved'] == 0 and after['paid'] == 2
    assert client.get('/api/v1/dashboard').json()['raised_cents'] == 9000

def test_retries_and_conflicts(client):
    request_id = str(uuid4())
    first = order(client, request_id=request_id)
    assert first.status_code == 200
    assert order(client, request_id=request_id).json()['id'] == first.json()['id']
    assert order(client, quantity=3, request_id=request_id).status_code == 409
    assert order(client, quantity=301).json()['error']['code'] == 'insufficient_capacity'

@pytest.mark.parametrize('quantity', [0, -1, 1.5, True])
def test_invalid_quantity(client, quantity):
    assert order(client, quantity).status_code == 422

def test_server_owned_fields_and_org_access(client):
    body = dict(name='Demo', quantity=1, event_id='abi-ball', request_id=str(uuid4()), price_cents=1)
    assert client.post('/api/v1/reservations', headers=HEADERS, json=body).status_code == 422
    assert client.get('/api/v1/reservations').status_code == 401

def test_cancel_releases_once_and_rejects_payment(client):
    ref = order(client).json()['id']
    for _ in range(2):
        assert client.post(f'/api/v1/reservations/{ref}/cancel', headers=HEADERS).status_code == 200
    assert client.get('/api/v1/events/abi-ball/availability').json()['available'] == 300
    assert client.post(f'/api/v1/reservations/{ref}/payment', headers=HEADERS).status_code == 409

def test_overdue_reservations_remain_held_and_can_be_extended(client):
    ref = order(client).json()['id']
    with client.app.state.database.connect(write=True) as db:
        db.execute('UPDATE reservations SET expires_at=? WHERE id=?', ('2000-01-01T00:00:00+00:00', ref))
    assert client.get(f'/api/v1/reservations/{ref}', headers=HEADERS).json()['overdue']
    assert client.get('/api/v1/events/abi-ball/availability').json()['available'] == 298
    response = client.post(f'/api/v1/reservations/{ref}/extend', headers=HEADERS, json={'days': 3})
    assert response.status_code == 200 and not response.json()['overdue']

def test_data_survives_application_restart(tmp_path):
    path = str(tmp_path / 'persistent.sqlite3')
    with TestClient(create_app(path, 'local-test-token')) as first:
        ref = order(first).json()['id']
    with TestClient(create_app(path, 'local-test-token')) as second:
        assert second.get(f'/api/v1/reservations/{ref}', headers=HEADERS).status_code == 200
        assert second.get('/api/v1/events/abi-ball/availability').json()['available'] == 298

def test_concurrent_last_ticket(tmp_path):
    path = str(tmp_path / 'concurrent.sqlite3')
    app = create_app(path, 'local-test-token')
    with TestClient(app) as setup:
        assert order(setup, quantity=299).status_code == 200
        def attempt(_):
            # Independent HTTP clients, shared file-backed database.
            with TestClient(create_app(path, 'local-test-token')) as client:
                return order(client, quantity=1).status_code
        with ThreadPoolExecutor(max_workers=2) as pool:
            assert sorted(pool.map(attempt, range(2))) == [200, 409]
        assert setup.get('/api/v1/events/abi-ball/availability').json()['available'] == 0


def test_dashboard_counts_ledger_net_and_ignores_unpaid_reservations(client):
    assert order(client, quantity=3).status_code == 200
    with client.app.state.database.connect(write=True) as db:
        db.execute('INSERT INTO ledger (action_id, amount_cents, description) VALUES (?, ?, ?)',
                   ('kiosk', 12000, 'Demo-Einnahme'))
        db.execute('INSERT INTO ledger (action_id, amount_cents, description) VALUES (?, ?, ?)',
                   ('kiosk', -3500, 'Demo-Ausgabe'))
    response = client.get('/api/v1/dashboard')
    assert response.status_code == 200
    assert response.json()['raised_cents'] == 8500


def test_dashboard_preserves_overfunding_and_negative_balance(client):
    with client.app.state.database.connect(write=True) as db:
        db.execute('INSERT INTO ledger (amount_cents, description) VALUES (?, ?)', (1800000, 'Demo'))
    assert client.get('/api/v1/dashboard').json()['progress_percent'] == 120.0
    with client.app.state.database.connect(write=True) as db:
        db.execute('INSERT INTO ledger (amount_cents, description) VALUES (?, ?)', (-1900000, 'Demo-Ausgabe'))
    assert client.get('/api/v1/dashboard').json()['raised_cents'] == -100000


def test_extension_retries_are_idempotent_and_reject_changed_payload(client):
    from datetime import datetime, timedelta
    ref = order(client).json()['id']
    other_ref = order(client, quantity=1).json()['id']
    before = client.get(f'/api/v1/reservations/{ref}', headers=HEADERS).json()
    key = str(uuid4())
    body = {'days': 3, 'request_id': key}
    first = client.post(f'/api/v1/reservations/{ref}/extend', headers=HEADERS, json=body)
    assert first.status_code == 200
    for _ in range(2):
        repeated = client.post(f'/api/v1/reservations/{ref}/extend', headers=HEADERS, json=body)
        assert repeated.json()['expires_at'] == first.json()['expires_at']
    assert datetime.fromisoformat(first.json()['expires_at']) - datetime.fromisoformat(before['expires_at']) == timedelta(days=3)
    assert client.post(f'/api/v1/reservations/{ref}/extend', headers=HEADERS,
                       json={'days': 4, 'request_id': key}).status_code == 409
    assert client.post(f'/api/v1/reservations/{other_ref}/extend', headers=HEADERS, json=body).status_code == 409
    assert client.get('/api/v1/dashboard').json()['raised_cents'] == 0
    assert client.get('/api/v1/events/abi-ball/availability').json()['reserved'] == 3


def test_extension_request_survives_backend_restart(tmp_path):
    path = str(tmp_path / 'extension.sqlite3')
    body = {'days': 3, 'request_id': str(uuid4())}
    with TestClient(create_app(path, 'local-test-token')) as first:
        ref = order(first).json()['id']
        deadline = first.post(f'/api/v1/reservations/{ref}/extend', headers=HEADERS, json=body).json()['expires_at']
    with TestClient(create_app(path, 'local-test-token')) as second:
        retried = second.post(f'/api/v1/reservations/{ref}/extend', headers=HEADERS, json=body)
        assert retried.status_code == 200
        assert retried.json()['expires_at'] == deadline


def test_schema_v1_upgrade_preserves_reservations(tmp_path):
    from appi.db import Database
    path = str(tmp_path / 'migration.sqlite3')
    with TestClient(create_app(path, 'local-test-token')) as client:
        saved = order(client).json()
    # Reconstruct the previous schema version without the added request table.
    with Database(path).connect(write=True) as db:
        db.execute('DROP TABLE reservation_extensions')
        db.execute('PRAGMA user_version=1')
    with TestClient(create_app(path, 'local-test-token')) as client:
        assert client.get(f"/api/v1/reservations/{saved['id']}", headers=HEADERS).json() == saved
        with client.app.state.database.connect() as db:
            assert db.execute('PRAGMA user_version').fetchone()[0] == 2
