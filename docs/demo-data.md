# Demo-Inhalte und Reset (SDA-8 / SDA-14)

Kiosk und Verkaufsstände laden ihre Inhalte über `GET /api/v1/demo-content`.
Angebote, Namen, Orte und Termine sind fiktive Beispiele. Finanzzahlen werden
bei jedem Abruf aus dem aktuellen Ledger berechnet: Einnahmen minus Ausgaben.
Es werden keine bereits bezahlten Ticketumsätze in die Aktionen hineingerechnet.
Lokale Canvas-Illustrationen passen zur bestehenden Campusgrafik. Keine Bilder,
Schriften oder Inhalte müssen zur Laufzeit aus dem Internet geladen werden.

## Lokal aktualisieren und prüfen

Nach Checkout von `feature/SDA-8-14-demo-content` aus dem Repository-Root:

```bash
backend/.venv/bin/python -m pytest -q backend/tests
cd app
flutter analyze
flutter test
```

Es kommen keine weiteren Pakete hinzu. Der Reset ist nach dem Checkout verfügbar,
wird aber niemals automatisch beim App-/Backend-Start ausgeführt. Vorhandene
Daten bleiben bis zum ausdrücklich angeforderten Reset erhalten.

## Komfortabler Demo-Reset

1. App mit `q` beenden und Backend mit Ctrl+C stoppen.
2. `Reset-AppI-Demo.command` im Finder doppelt anklicken.
3. Den Text lesen und zum bewussten Zurücksetzen exakt **RESET** eingeben.
4. Backend über den bestehenden Link neu starten, App mit `flutter run` starten.

Die Datei darf wie die anderen Starter lokal umbenannt werden. Sie findet das
Repository über ihren eigenen Speicherort und muss im Repository-Root bleiben.

Vor dem Zurücksetzen wird die bisherige SQLite-Datenbank mittels SQLite-Backup
unter `backend/data/backups/` gesichert. Der Token in `backend/data/org-token`
bleibt unverändert. Ein belegter lokaler Backend-Port verhindert den Reset.
Bei abweichendem Backend-Port unten den passenden `--port` angeben; das Backend
muss tatsächlich gestoppt sein. Die Skripte beenden keine laufenden Prozesse.

Nach jedem Reset App vollständig neu starten, damit alte Formular-/Org-Sitzungen
keine veralteten Daten behalten. Das Backend muss nach dem Reset wieder starten.
Backups und Datenbankdateien liegen im Git-ignorierten Datenverzeichnis.

## Terminal-Varianten

Aus dem Repository-Root, bei gestopptem Backend und beendeter App:

```bash
backend/.venv/bin/python -m appi.demo reset --confirm RESET
```

Vollständig leere Abikasse mit allen Karten verfügbar; Angebote und Beispieltexte
bleiben nutzbar und zeigen 0 EUR Beitrag:

```bash
backend/.venv/bin/python -m appi.demo reset --scenario empty --confirm RESET
```

Optionen: `--school`, `--year`, `--target-cents`, `--ticket-price-cents`,
`--capacity`, `--reservation-days`, `--db`, `--port`. Beispiel für einen anderen
Jahrgang und Ticketpreis (alle Beträge in Cent):

```bash
backend/.venv/bin/python -m appi.demo reset --confirm RESET --year 2028 --ticket-price-cents 5000
```

Der Demo-Stand benötigt mindestens sieben Karten Kontingent. Fristen richten
sich nach dem tatsächlichen Reset-Zeitpunkt: offen in der Zukunft, überfällig
seit gestern. `--at <ISO-8601 mit Zeitzone>` dient reproduzierbaren Zeitpunkten,
z.B. in lokalen Tests. Die API-Uhr wird dadurch nicht eingefroren; ein historisch
gewählter Zeitpunkt kann in der laufenden App auch offene Fristen überfällig
erscheinen lassen. Für die Vorführung `--at` weglassen.

Es gibt keinen HTTP-Endpunkt für den Reset und keine Reset-Funktion in der App.

## Definierter Demo-Ausgangsstand

| Quelle | Einnahmen | Ausgaben | Beitrag |
|---|---:|---:|---:|
| Schulkiosk | 860,00 EUR | 260,00 EUR | 600,00 EUR |
| Schulfest | 720,00 EUR | 180,00 EUR | 540,00 EUR |
| Leseabend | 240,00 EUR | 60,00 EUR | 180,00 EUR |
| Sportfest | 410,00 EUR | 110,00 EUR | 300,00 EUR |
| Bezahlte Karten: 3 × 45,00 EUR | 135,00 EUR | 0,00 EUR | 135,00 EUR |
| **Abikasse** | | | **1.755,00 EUR** |

Ziel 15.000 EUR, Fortschritt 11,7 %. Kiosk-/Aktionssummen ergeben zusammen
1.620 EUR. Offene Reservierungen werden nicht als Einnahmen gezählt.

| Referenz | Name | Menge | Zustand |
|---|---|---:|---|
| ABI-DEMO-OFFEN | Lina Beispiel | 2 | Offen, Frist in der Zukunft |
| ABI-DEMO-BEZAHLT | Nora Muster | 3 | Bezahlt |
| ABI-DEMO-UEBERFAELLIG | Alex Demofall | 2 | Überfällig, Karten bleiben reserviert |
| ABI-DEMO-STORNIERT | Sam Demofall | 1 | Storniert, keine Karten belegt |

**300 Karten = 293 verfügbar + 4 reserviert + 3 bezahlt.** Die stornierten Karten
werden nicht belegt. Referenzen sind für diese geschützten lokalen Demo-Fälle
bewusst fest; neue Reservierungen erhalten weiterhin zufällige Referenzen.

Eine zusätzliche Reservierung für zwei Karten hält zwei weitere Karten frei:
291 verfügbar, sechs reserviert, drei bezahlt. Nach deren Zahlungsbestätigung
stehen 291 verfügbar, vier reserviert und fünf bezahlt; die Abikasse steigt
auf 1.845 EUR. Bei geändertem Ticketpreis ändern sich diese Beträge entsprechend.

## Erweiterung während der Vorführung

- Eine zusätzliche `ExpandableInfo` unter einer Aktion oder im Kiosk ergänzen.
- Einen Informations-Chip interaktiv machen, z.B. eine Helfer-Notiz öffnen.
- Ein weiteres Angebot oder eine zusätzliche Schichtinformation ergänzen.

Es gibt bewusst keinen Warenkorb, Helferplaner oder Zahlungsanbieter in den
Dummy-Bereichen. Die Inhalte bieten Anknüpfungspunkte für Schülerideen.
Card-Größen bleiben unverändert; PMG-Branding folgt separat.

## Daten und technische Grenzen

`backend/appi/demo_data.json` enthält den gemeinsamen Beispieldatensatz,
Angebote, Aktionen, Kontakte und Reset-Konfiguration. Nur die öffentliche
Inhalts-/Finanzansicht wird über `/demo-content` ausgegeben. Reservierungsnamen,
Referenzen und Verwaltungsaktionen bleiben in den Org-geschützten Endpunkten.
Standard-Start ohne Reset bleibt wie bisher leer; er spielt keine Demo-Umsätze ein.

Schulname/Jahrgang/Ziel/Preis/Kontingent/Reservierungsdauer sind beim Reset
konfigurierbar. Produktpreise und Aktionsbeschreibungen bleiben fiktive
Beispielinhalte. Die zwei Kontakte entsprechen den bisherigen Org-Dummy-Kontakten.
Die Canvas-Illustrationen sind eigene geometrische Symbole, keine PMG-Bilder.

## Prüfstand

Tests für Summen, Bestand, Fristfälle, Wiederholbarkeit, Sicherung, leeren Stand,
Konfiguration und die CLI-Schutzbedingungen sind angelegt. Flutter-Tests prüfen
Finanzkonsistenz, Navigation, Angebote, aufklappbare Inhalte, Fehler/Retry und
schmale Darstellung. Tests verwenden lokale Fakes und temporäre Datenbanken.

Die KI hat keine Tests, keinen Flutter-Analyzer, keinen Simulator-Build und
keinen Reset einer Benutzerdatenbank ausgeführt. Python-/Shell-Syntax und
`git diff --check` wurden geprüft. Die visuelle Abnahme erfolgt im Simulator.

Führe keine Tests aus – diese müssen vollständig lokal über VS Code laufen.
