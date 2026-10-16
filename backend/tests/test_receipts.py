"""Ausführen ausschließlich lokal über VS Code, nicht durch die KI."""
from io import BytesIO
from uuid import uuid4

import pytest
import pypdfium2
import zxingcpp
from fastapi.testclient import TestClient
from pypdf import PdfReader

from appi.main import create_app
from appi.receipts import DEMO_IBAN, DEMO_RECIPIENT, qr_target

HEADERS = {'Authorization': 'Bearer receipt-test-token'}


@pytest.fixture
def client(tmp_path):
    with TestClient(create_app(str(tmp_path / 'receipt.sqlite3'), 'receipt-test-token')) as c:
        yield c


def reserve(client, name='Lina & Amélie <Beispiel>'):
    return client.post('/api/v1/reservations', headers=HEADERS, json={
        'request_id': str(uuid4()), 'event_id': 'abi-ball', 'name': name, 'quantity': 2,
    }).json()


def text(pdf):
    return '\n'.join(page.extract_text() for page in PdfReader(BytesIO(pdf)).pages)


def test_receipt_uses_saved_data_with_readable_qr_and_no_mutation(client):
    saved = reserve(client)
    with client.app.state.database.connect(write=True) as db:
        # The receipt must use the reservation's price snapshot, not today's event price.
        db.execute("UPDATE events SET price_cents=5100 WHERE id='abi-ball'")
    stock_before = client.get('/api/v1/events/abi-ball/availability').json()
    response = client.get(f"/api/v1/reservations/{saved['id']}/receipt.pdf", headers=HEADERS)
    assert response.status_code == 200
    assert response.headers['content-type'].startswith('application/pdf')
    assert response.headers['cache-control'] == 'no-store'
    assert response.content.startswith(b'%PDF-')
    content = text(response.content)
    for expected in [saved['id'], saved['name'], '45,00 €', '90,00 €', 'Abiball 2027 (Demo)',
                     DEMO_IBAN, DEMO_RECIPIENT, 'noch keine Eintrittskarte', 'Nicht überweisen!',
                     'Europe/Berlin']:
        assert expected in content
    assert 'receipt-test-token' not in content
    assert 'Bearer' not in content
    # Decode the QR from the actual PDF page; not just the QR-source helper.
    document = pypdfium2.PdfDocument(response.content)
    try:
        codes = []
        for page in document:
            bitmap = page.render(scale=2.5)
            codes.extend(code.text for code in zxingcpp.read_barcodes(bitmap.to_pil()))
            bitmap.close()
            page.close()
        assert codes == [qr_target(saved['id'])]
    finally:
        document.close()
    assert client.get('/api/v1/events/abi-ball/availability').json() == stock_before
    assert client.get('/api/v1/dashboard').json()['raised_cents'] == 0


def test_receipt_requires_org_access_and_unknown_reference_is_404(client):
    saved = reserve(client)
    url = f"/api/v1/reservations/{saved['id']}/receipt.pdf"
    assert client.get(url).status_code == 401
    assert client.get(url, headers={'Authorization': 'Bearer wrong'}).status_code == 401
    assert client.get('/api/v1/reservations/not-a-reference/receipt.pdf', headers=HEADERS).status_code == 404


def test_receipt_reloads_current_status_and_extended_deadline(client):
    saved = reserve(client)
    reference = saved['id']
    extended = client.post(f'/api/v1/reservations/{reference}/extend', headers=HEADERS, json={'days': 3}).json()
    first = client.get(f'/api/v1/reservations/{reference}/receipt.pdf', headers=HEADERS)
    from appi.receipts import local_time
    assert local_time(extended['expires_at']) in text(first.content)
    client.post(f'/api/v1/reservations/{reference}/payment', headers=HEADERS)
    paid = client.get(f'/api/v1/reservations/{reference}/receipt.pdf', headers=HEADERS)
    assert 'Keine weitere Zahlung erforderlich.' in text(paid.content)


def test_long_name_is_preserved_and_markup_is_escaped(client):
    name = 'ÄÖÜß & < > ' + 'LangerName' * 10
    saved = reserve(client, name=name)
    response = client.get(f"/api/v1/reservations/{saved['id']}/receipt.pdf", headers=HEADERS)
    assert response.status_code == 200
    compact = ''.join(text(response.content).split())
    assert ''.join(name.split()) in compact
    assert len(PdfReader(BytesIO(response.content)).pages) <= 2
