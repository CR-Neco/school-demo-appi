# REST-Vertrag v1

Base URL lokal: `http://127.0.0.1:8000/api/v1`.
Die spätere Flutter-App erhält diese Adresse als Konfiguration (geplant:
`--dart-define=APPI_API_BASE_URL=...`). Keine direkten Datenbankzugriffe.

| Methode / Pfad | Ergebnis | Org-Token |
|---|---|---|
| GET /config | Schule, Jahrgang, Ziel in Cent, Reservierungsdauer | nein |
| GET /actions | Kiosk und Verkaufsaktionen (minimale Stammdaten) | nein |
| GET /events | Veranstaltungen, Preis in Cent und Kontingent | nein |
| GET /events/{id}/availability | available, reserved, paid, capacity | nein |
| GET /dashboard | target_cents, raised_cents, progress_percent | nein |
| POST /reservations | Reservierung erstellen oder sichere Wiederholung | ja |
| GET /reservations | Org-Liste mit Status und Frist | ja |
| GET /reservations/{reference} | Reservierungsdetail | ja |
| POST /reservations/{reference}/payment | Vollzahlung bestätigen | ja |
| POST /reservations/{reference}/extend | Offene Frist verlängern | ja |
| POST /reservations/{reference}/cancel | Offene Reservierung stornieren | ja |

Org-Header: `Authorization: Bearer <APPI_ORG_TOKEN>`.
In Demo 1 keine öffentliche Käufer-Selbstbedienung, keine Bank-Schnittstelle.
POST /reservations liefert 200, auch beim idempotenten Wiederholen.

Anlage-Body:

```json
{"request_id":"f509a8bc-58c1-43bc-80a0-92bd356df23e","event_id":"abi-ball","name":"Demo Beispiel","quantity":2}
```

Client erzeugt eine UUID pro beabsichtigter Bestellung und verwendet dieselbe
UUID bei Netzwerk-Retries. Gleiche UUID mit anderem Inhalt ergibt 409.
Preis, Frist, Status und Gesamtbetrag dürfen nicht mitgeschickt werden (422).
Serverantwort enthält Referenz `id`, event_id, name, quantity, price_cents,
total_cents, status, created_at, expires_at, paid_at (nullable) und overdue.
Zeitstempel sind UTC/ISO 8601. IDs sind opak, nicht zerlegen oder selbst erzeugen.

Verlängerung: `{"days":3}` bedeutet drei Tage ab späterem Zeitpunkt von
jetzt und bisherigem Ablauf. Zahlung/Storno brauchen keinen Request-Body.
Status: reserved -> paid oder cancelled; beide Endzustände können nicht verlängert
werden. Zahlung und Storno sind beim Wiederholen desselben Zustands idempotent.
Bezahlte Buchungen stornieren sowie stornierte Buchungen bezahlen ergibt 409.

Fehlerformat:

```json
{"error":{"code":"insufficient_capacity","message":"Nicht genügend Karten verfügbar."}}
```

401 fehlender/falscher Org-Zugang; 404 unbekannte Veranstaltung/Reservierung;
409 Bestands-/Zustands-/Request-Konflikt; 422 ungültige Eingaben/unerlaubte Felder;
503 fehlende Org-Konfiguration oder Datenbank vorübergehend nicht verfügbar;
500 unerwarteter interner Fehler. Antworten enthalten keine Stacktraces.

Dashboard: bestätigte Einnahmen minus Ausgaben im Ledger. Negative Ledger-Werte
sind Ausgaben; jede Ticketzahlung hat einen eindeutigen Reservierungsbezug.
Unbezahlte Reservierungen sind keine Einnahmen. Betrag kann negativ oder über dem
Ziel liegen; visuelle Begrenzung des Balkens erfolgt später im Frontend.

## Demo-Grenzen

Nur lokaler Zugriff. Kein öffentliches Reservierungsportal, kein Käufer-Link,
PDF oder Scanner in SDA-5. QR/Beleg folgt SDA-12, Website SDA-18. Der Org-Token
wird nicht im QR hinterlegt. Demo-Frist standardmäßig fünf Tage, Ticketpreis
45 EUR und 300 Karten; dies sind fiktive Bootstrap-Werte, keine PMG-Angaben.
Erweiterte Seed-Daten/Reset folgen SDA-8.
