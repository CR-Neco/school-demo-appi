# Architekturentscheidung SDA-5

Status: umgesetzt als lokale Demo-Grundlage.

Flutter (folgt SDA-9) -> HTTP/JSON REST /api/v1 -> Python FastAPI -> SQLite-Datei.

SQLite vermeidet für den Vortrag Docker, Datenbankkonten und einen zusätzlichen
Serverprozess. Die Daten liegen persistent im Backend, nicht im Simulator.
Python 3.11+ ist Voraussetzung. Geld wird ausschließlich in Integer-Cent geführt;
Zeitstempel sind UTC mit Zeitzone, Anzeige später Europe/Berlin.

Das Backend ist ein lokales Demo-System, kein öffentlich betreibbares Produkt.
Bindung nur an 127.0.0.1. Org-Aufrufe benötigen einen selbst gewählten Demo-Token
aus der Umgebung. Er ersetzt keine echte Nutzerverwaltung. Keine echten Personen,
Kontodaten oder Zahlungen verwenden. Konfiguration wird nur lokal gepflegt.

Verfügbarkeit und Zustandswechsel erfolgen in SQLite-Schreibtransaktionen mit
BEGIN IMMEDIATE. Damit werden konkurrierende Schreibzugriffe serialisiert.
Unbezahlte aktive Reservierungen blockieren Karten auch nach Ablauf ihrer Frist.
Erst ein bewusstes Storno gibt sie frei. Zahlungseingänge werden hier manuell
bestätigt; der Server setzt Preis und Frist und bucht pro Reservierung höchstens
eine Einnahme. Konkrete Härte-/Parallelitätstests und Ausbau: SDA-6/SDA-7/SDA-15.

Für Schulserver/Cloud kann derselbe API-Vertrag erhalten bleiben. Ein Wechsel auf
PostgreSQL erfordert eine angepasste Persistenzschicht, Datenmigration und passende
Transaktions-/Sperrlogik; er ist kein bloßer URL-Tausch. Zusätzlich erforderlich:
HTTPS, Nutzer/Rollen, Backups, Monitoring und ein passendes Betriebskonzept.
Kein direkter SQL-Zugriff aus der App, keine Datenbankpasswörter im Client.

API-Vertrag: FastAPI /openapi.json, lokale interaktive Dokumentation /docs,
kompakte Beschreibung in api.md. Kein PDF-/Bank-/Cloud-Dienst im Unterbau.
Schema v1: automatische Erstanlage, keine automatische Migration bestehender Schemata.
