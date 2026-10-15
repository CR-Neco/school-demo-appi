"""Ausführen ausschließlich lokal über VS Code, nicht durch die KI."""
from datetime import datetime, timezone
import socket
import sqlite3
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from appi import service
from appi.demo import main, reset_database
from appi.main import create_app

NOW = datetime(2027, 5, 1, 12, tzinfo=timezone.utc)
HEADERS = {'Authorization': 'Bearer demo-test-token'}


def test_demo_stock_finances_deadlines_and_catalog_are_consistent(tmp_path, monkeypatch):
    monkeypatch.setattr(service, 'now', lambda: NOW)
    path = tmp_path / 'demo.sqlite3'
    reset_database(path, at=NOW)
    with TestClient(create_app(str(path), 'demo-test-token')) as client:
        stock = client.get('/api/v1/events/abi-ball/availability').json()
        assert stock == {'event_id': 'abi-ball', 'available': 293, 'reserved': 4, 'paid': 3, 'capacity': 300}
        dashboard = client.get('/api/v1/dashboard').json()
        assert dashboard['raised_cents'] == 175500
        assert dashboard['progress_percent'] == 11.7
        content = client.get('/api/v1/demo-content').json()
        assert content['is_demo']
        assert len(content['actions']) == 3 and len(content['kiosk']['products']) == 4
        net = sum(item['raised_cents'] for item in [content['kiosk'], *content['actions']])
        assert net == 162000
        assert net + 3 * 4500 == dashboard['raised_cents']
        assert 'reservations' not in content and 'config' not in content
        assert 'seed_income_cents' not in content['kiosk']
        rows = client.get('/api/v1/reservations', headers=HEADERS).json()
        by_id = {row['id']: row for row in rows}
        assert by_id['ABI-DEMO-UEBERFAELLIG']['overdue'] is True
        assert by_id['ABI-DEMO-OFFEN']['overdue'] is False
        assert by_id['ABI-DEMO-BEZAHLT']['status'] == 'paid'
        assert by_id['ABI-DEMO-STORNIERT']['status'] == 'cancelled'
        # Demo contacts/prices are public; personal reservation details remain guarded.
        assert client.get('/api/v1/reservations').status_code == 401


def test_reset_restores_state_and_keeps_backup_of_previous_sales(tmp_path, monkeypatch):
    monkeypatch.setattr(service, 'now', lambda: NOW)
    path = tmp_path / 'demo.sqlite3'
    reset_database(path, at=NOW)
    with TestClient(create_app(str(path), 'demo-test-token')) as client:
        reservation = client.post('/api/v1/reservations', headers=HEADERS, json={
            'event_id': 'abi-ball', 'name': 'Neuer Demofall', 'quantity': 2, 'request_id': str(uuid4()),
        }).json()
        client.post(f"/api/v1/reservations/{reservation['id']}/payment", headers=HEADERS)
        assert client.get('/api/v1/dashboard').json()['raised_cents'] == 184500
    backup = reset_database(path, at=NOW)
    assert backup and backup.exists()
    with sqlite3.connect(backup) as db:
        assert db.execute('SELECT SUM(amount_cents) FROM ledger').fetchone()[0] == 184500
    reset_database(path, at=NOW)
    with TestClient(create_app(str(path), 'demo-test-token')) as client:
        assert client.get('/api/v1/dashboard').json()['raised_cents'] == 175500
        assert len(client.get('/api/v1/reservations', headers=HEADERS).json()) == 4


def test_empty_scenario_has_no_phantom_income(tmp_path):
    path = tmp_path / 'empty.sqlite3'
    reset_database(path, scenario='empty', at=NOW)
    with TestClient(create_app(str(path), 'demo-test-token')) as client:
        assert client.get('/api/v1/dashboard').json()['raised_cents'] == 0
        assert client.get('/api/v1/events/abi-ball/availability').json()['available'] == 300
        content = client.get('/api/v1/demo-content').json()
        assert all(item['raised_cents'] == 0 for item in [content['kiosk'], *content['actions']])
        assert client.get('/api/v1/reservations', headers=HEADERS).json() == []


def test_custom_config_and_short_deadline_keep_open_and_overdue_cases(tmp_path, monkeypatch):
    monkeypatch.setattr(service, 'now', lambda: NOW)
    path = tmp_path / 'custom.sqlite3'
    reset_database(path, at=NOW, overrides={'school': 'Demo Schule', 'year': 2028,
        'ticket_price_cents': 5000, 'capacity': 100, 'target_cents': 2000000, 'reservation_days': 1})
    with TestClient(create_app(str(path), 'demo-test-token')) as client:
        assert client.get('/api/v1/config').json()['year'] == 2028
        assert client.get('/api/v1/events').json()[0]['price_cents'] == 5000
        assert client.get('/api/v1/dashboard').json()['raised_cents'] == 177000
        assert client.get('/api/v1/events/abi-ball/availability').json()['available'] == 93
        assert not client.get('/api/v1/reservations/ABI-DEMO-OFFEN', headers=HEADERS).json()['overdue']
        assert client.get('/api/v1/reservations/ABI-DEMO-UEBERFAELLIG', headers=HEADERS).json()['overdue']


def test_cli_requires_explicit_confirmation_and_refuses_live_port(tmp_path):
    path = tmp_path / 'untouched.sqlite3'
    with pytest.raises(SystemExit) as error:
        main(['reset', '--db', str(path)])
    assert error.value.code == 2 and not path.exists()
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        listener.listen()
        with pytest.raises(SystemExit) as error:
            main(['reset', '--confirm', 'RESET', '--db', str(path), '--port', str(listener.getsockname()[1])])
        assert error.value.code == 1 and not path.exists()


def test_invalid_seed_parameters_leave_database_untouched(tmp_path):
    path = tmp_path / 'untouched.sqlite3'
    with pytest.raises(ValueError):
        reset_database(path, at=NOW, overrides={'capacity': 6})
    assert not path.exists()
    with pytest.raises(ValueError):
        reset_database(path, at=NOW.replace(tzinfo=None))
    assert not path.exists()


def test_no_public_reset_route(tmp_path):
    with TestClient(create_app(str(tmp_path / 'api.sqlite3'), 'demo-test-token')) as client:
        assert client.post('/api/v1/reset', headers=HEADERS).status_code == 404
        assert client.post('/api/v1/demo-content/reset', headers=HEADERS).status_code == 404
