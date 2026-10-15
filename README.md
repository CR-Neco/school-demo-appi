# AppI 2027

Kleine AI-Coding-Demo zur Abiball-Organisation am PMG Meine.
Repository: school-demo-appi. Vorgängeridee: Golden Chalk Awards.

## Stand SDA-5

Lokales FastAPI-/SQLite-Backend, persistentes Schema, REST-Vertrag und erste
Buchungsoperationen. Flutter-Oberfläche folgt in SDA-9 ff.
Alle Inhalte sind fiktiv. Keine echten Zahlungen, Bankanbindung oder Nutzerkonten.

## Backend lokal starten (macOS / VS Code)

Voraussetzung: Python 3.11 oder neuer. Vom Repository-Root:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -e '.[dev]'
export APPI_ORG_TOKEN="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"
python -m uvicorn appi.main:app --host 127.0.0.1 --port 8000 --reload
```

API: http://127.0.0.1:8000/api/v1
Dokumentation: http://127.0.0.1:8000/docs
Schema: http://127.0.0.1:8000/openapi.json
Health: http://127.0.0.1:8000/health

SQLite wird bei Erststart in `backend/data/appi.sqlite3` angelegt. Neustart
behält Daten. Optional `APPI_DB_PATH` als absoluten Pfad setzen. `.env.example`
ist eine Vorlage, kein automatisch geladener Secret-Speicher. Org-Token nicht
committen. Ohne Token bleiben Org-Endpunkte gesperrt.

Org-Anfragen senden `Authorization: Bearer <lokaler Token>`.
Für VS-Code-Tasks den Token in der Umgebung setzen, bevor VS Code aus diesem
Terminal gestartet wird, oder den Start im integrierten Terminal durchführen.
Tokens werden nicht als Task-Argumente oder im Repository gespeichert.

## Tests ausschließlich lokal

VS Code: **Terminal -> Task ausführen -> AppI: Backend-Tests lokal**.
Alternativ im integrierten Terminal, nach Aktivierung der venv:

```bash
cd backend  # nur falls noch im Repository-Root
python -m pytest -q
```

Tests verwenden ausschließlich temporäre Datenbanken und fiktive Daten. Sie sind
angelegt, wurden durch den KI-Agenten nicht ausgeführt. Laufzeit-/Installations-
und Testabnahme auf dem lokalen Mac steht aus; keine grüne Testsuite behauptet.

Live-Prompt-Zusatz:

> Führe keine Tests aus – diese müssen vollständig lokal über VS Code laufen.

## Entwicklung und nächste Schritte

- SDA-5: API-/Datenmodell-Grundlage; lokale Abnahme steht aus.
- SDA-6/7: Buchungsregeln härten und nach lokaler Testausführung abnehmen.
- SDA-8: reichhaltige, zeitlich reproduzierbare Seed-Szenarien und Reset-Befehl.
- SDA-9 ff.: Simulator-App, PDF/QR, Org-Ansicht und Dashboard.
- SDA-15/16: zusätzliche Tests, Generalprobe und späterer Live-Demo-Branch.
- SDA-18: Website später, keine Voraussetzung für diese Demo.

[Architekturentscheidung](docs/architecture.md) · [API-Vertrag](docs/api.md)

Noch keine Lizenzentscheidung getroffen; öffentliche Sichtbarkeit allein ist
keine Open-Source-Lizenz. Klärung von Code-/Asset-Lizenz erfolgt in SDA-17.
