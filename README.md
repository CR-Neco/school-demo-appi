# PMG AppI

Kleine AI-Coding-Demo zur Abiball-Organisation am PMG Meine.
Repository: school-demo-appi. Vorgängeridee: Golden Chalk Awards.

## Stand SDA-5

Lokales FastAPI-/SQLite-Backend, persistentes Schema, REST-Vertrag und erste
Buchungsoperationen. Flutter-Grundoberfläche ist in SDA-9 vorbereitet; lokale Simulator-Abnahme steht aus.
Alle Inhalte sind fiktiv. Keine echten Zahlungen, Bankanbindung oder Nutzerkonten.

## Simulator-App starten

Backend separat laufen lassen, dann im Finder **Start-AppI-Simulator.command**
doppelt anklicken. Die App öffnet sich im iOS-Simulator. Alternativ in VS Code:

```bash
cd app
python3 tool/prepare_ios.py
flutter pub get
python3 tool/run_simulator.py
```

[Ausführliche Simulator-Anleitung](docs/simulator.md). Kartenverkauf und
Finanzierungsanzeige folgen in den nächsten Tickets.

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

## Komfortstart per Doppelklick (macOS)

Nach der einmaligen Python-/venv-Einrichtung im Finder im Projektordner
**backend_appi.command** doppelt anklicken. Ein separates Terminalfenster
startet das Backend unabhängig von VS Code. Fenster offen lassen, stoppen mit
**Ctrl+C**. Beim nächsten Mal reicht wieder ein Doppelklick.

Falls bereits ein Server aus VS Code läuft: diesen zuerst mit Ctrl+C stoppen.
Der Starter erkennt einen belegten Port 8000 und beendet keine anderen Prozesse.
Es werden keine Tests oder Paketinstallationen automatisch ausgeführt.

Ohne bereits gesetzten `APPI_ORG_TOKEN` erzeugt der Starter einmalig einen lokalen
Demo-Token in `backend/data/org-token` (nur für den Benutzer lesbar, Git-ignoriert)
und verwendet ihn bei weiteren Starts erneut. Er wird nicht ausgegeben. Der
spätere Simulator-Client muss denselben Wert als Org-Token erhalten; automatische
Flutter-Anbindung folgt mit der App. Das ist kein produktives Login-System.

Der Starter verwendet standardmäßig `backend/data/appi.sqlite3`. Ein ausdrücklich
in seiner Umgebung gesetzter `APPI_DB_PATH` hat Vorrang. Die Datei `.env` wird
weiterhin nicht automatisch eingelesen.

Wenn macOS fehlende Ausführungsrechte meldet, einmal im Projektordner:

```bash
chmod +x backend_appi.command
```

## Tests ausschließlich lokal

VS Code: **Terminal -> Task ausführen -> AppI: Backend-Tests lokal**.
Alternativ im integrierten Terminal, nach Aktivierung der venv:

```bash
cd backend  # nur falls noch im Repository-Root
python -m pytest -q
```

Backend-Tests verwenden ausschließlich temporäre Datenbanken und fiktive Daten.
Lokal durch Christian geprüft: 11 Tests erfolgreich, Backend-Start und API-Aufruf
bestätigt. Der KI-Agent hat keine Tests ausgeführt. Neue Flutter-Tests und der
Simulator-Build aus SDA-9 müssen separat lokal geprüft werden.

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
