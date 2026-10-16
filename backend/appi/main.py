import logging
import os
import secrets
import sqlite3
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, FastAPI, Header
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, Response
from starlette.exceptions import HTTPException

from .db import Database
from . import schemas as s, service

logger = logging.getLogger(__name__)

def create_app(db_path: str | None = None, org_token: str | None = None):
    default_path = Path(__file__).resolve().parents[1] / 'data' / 'appi.sqlite3'
    database = Database(db_path or os.environ.get('APPI_DB_PATH', str(default_path)))
    token = org_token if org_token is not None else os.environ.get('APPI_ORG_TOKEN', '')

    @asynccontextmanager
    async def lifespan(app):
        database.initialize()
        yield

    app = FastAPI(title='PMG AppI – lokale Demo-API', version='0.1.0', lifespan=lifespan)
    app.state.database = database

    def error(status, code, message):
        return JSONResponse(status_code=status, content={'error': {'code': code, 'message': message}})

    @app.exception_handler(service.DomainError)
    async def domain_error(request, exc):
        return error(exc.status, exc.code, exc.message)

    @app.exception_handler(RequestValidationError)
    async def validation_error(request, exc):
        return error(422, 'validation_error', 'Eingaben fehlen, sind ungültig oder enthalten unerlaubte Felder.')

    @app.exception_handler(HTTPException)
    async def http_error(request, exc):
        return error(exc.status_code, 'http_error', 'Anfrage konnte nicht verarbeitet werden.')

    @app.exception_handler(sqlite3.OperationalError)
    async def database_error(request, exc):
        logger.exception('Database operation failed')
        return error(503, 'database_unavailable', 'Datenbank vorübergehend nicht verfügbar. Bitte erneut versuchen.')

    @app.exception_handler(Exception)
    async def internal_error(request, exc):
        logger.exception('Unexpected backend error')
        return error(500, 'internal_error', 'Interner Fehler. Bitte das Demo-Team informieren.')

    def org_access(authorization: Annotated[str | None, Header()] = None):
        if not token:
            raise service.DomainError(503, 'org_not_configured', 'APPI_ORG_TOKEN muss lokal gesetzt werden.')
        expected = ('Bearer ' + token).encode()
        if authorization is None or not secrets.compare_digest(authorization.encode(), expected):
            raise service.DomainError(401, 'org_unauthorized', 'Demo-Org-Zugang erforderlich.')

    router = APIRouter(prefix='/api/v1', responses={
        code: {'model': s.ErrorResponse} for code in (401, 404, 409, 422, 500, 503)})
    org = [Depends(org_access)]

    @app.get('/health')
    def health():
        return {'status': 'ok', 'mode': 'local-demo'}

    @router.get('/config', response_model=s.Configuration)
    def config():
        with database.connect() as db:
            row = dict(db.execute('SELECT * FROM config WHERE id=1').fetchone())
            row.pop('id')
            return row

    @router.get('/actions', response_model=list[s.Action])
    def actions():
        with database.connect() as db:
            return [dict(row) for row in db.execute('SELECT * FROM actions ORDER BY id')]

    @router.get('/events', response_model=list[s.Event])
    def events():
        with database.connect() as db:
            return [dict(row) for row in db.execute('SELECT * FROM events ORDER BY id')]

    @router.get('/events/{event_id}/availability', response_model=s.Availability)
    def availability(event_id: str):
        with database.connect() as db:
            return service.availability(db, event_id)

    @router.get('/dashboard', response_model=s.Dashboard)
    def dashboard():
        with database.connect() as db:
            target = db.execute('SELECT target_cents FROM config WHERE id=1').fetchone()[0]
            raised = db.execute('SELECT COALESCE(SUM(amount_cents), 0) FROM ledger').fetchone()[0]
            return dict(target_cents=target, raised_cents=raised,
                        progress_percent=round(raised/target*100, 2))

    @router.post('/reservations', response_model=s.Reservation, dependencies=org)
    def reserve(data: s.ReservationCreate):
        with database.connect(write=True) as db:
            return service.reserve(db, data)

    @router.get('/reservations', response_model=list[s.Reservation], dependencies=org)
    def reservations():
        with database.connect() as db:
            return [service.present(dict(row)) for row in db.execute(
                'SELECT * FROM reservations ORDER BY created_at DESC, id')]

    @router.get('/reservations/{reference}', response_model=s.Reservation, dependencies=org)
    def reservation(reference: str):
        with database.connect() as db:
            return service.present(service.get_reservation(db, reference))

    @router.get('/reservations/{reference}/receipt.pdf', dependencies=org,
                response_class=Response, responses={200: {'content': {'application/pdf': {}}}})
    def receipt(reference: str):
        # Read all document fields in the same database snapshot. No mutation.
        with database.connect() as db:
            reservation = service.present(service.get_reservation(db, reference))
            event = service.get_event(db, reservation['event_id'])
            school = db.execute('SELECT school FROM config WHERE id=1').fetchone()[0]
        from .receipts import render_receipt
        pdf = render_receipt(reservation, event, school)
        return Response(content=pdf, media_type='application/pdf', headers={
            'Content-Disposition': 'inline; filename="reservierungsbeleg.pdf"',
            'Cache-Control': 'no-store',
            'X-Content-Type-Options': 'nosniff',
        })

    @router.post('/reservations/{reference}/payment', response_model=s.Reservation, dependencies=org)
    def payment(reference: str):
        with database.connect(write=True) as db:
            return service.confirm_payment(db, reference)

    @router.post('/reservations/{reference}/cancel', response_model=s.Reservation, dependencies=org)
    def cancel(reference: str):
        with database.connect(write=True) as db:
            return service.cancel(db, reference)

    @router.post('/reservations/{reference}/extend', response_model=s.Reservation, dependencies=org)
    def extend(reference: str, data: s.Extension):
        with database.connect(write=True) as db:
            return service.extend(db, reference, data.days, data.request_id)

    app.include_router(router)
    return app

app = create_app()
