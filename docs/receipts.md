# Reservierungsbeleg als PDF (SDA-12)

Nach erfolgreicher Reservierung führt **PDF-Beleg öffnen** zur PDF-Vorschau.
**PDF teilen** oben rechts öffnet das native Teilen-Menü. Die App lädt die Bytes
beim Öffnen frisch aus dem Backend; sie erzeugt keine zweite Reservierung.
Die bisherige Datenübersicht bleibt zusätzlich erreichbar.

## Einmalige Aktualisierung auf dem Mac

Flutter mit `q` beenden; Backend im separaten Fenster mit Ctrl+C stoppen.
Nach Checkout von `feature/SDA-12-pdf-receipts` aus dem Repository-Root:

```bash
backend/.venv/bin/python -m pip install -e './backend[dev]'
backend/.venv/bin/python -m pytest -q backend/tests
cd app
flutter pub get
flutter analyze
flutter test
```

`flutter pub get` aktualisiert erwartungsgemäß `app/pubspec.lock`, weil mit
`printing` erstmals ein natives Plugin hinzukommt. Die Lockdatei wird nicht
von Hand angepasst und soll nach der lokalen Abnahme mit eingecheckt werden.
Die vorhandene Flutter-/Dart-Installation des Vortragenden ist die Zielumgebung;
bei älteren SDKs kann die Paketauflösung eine ältere kompatible Version wählen.

Backend über die bestehende `.command` neu starten. Danach aus `app/`:

```bash
flutter run
```

Ein bloßer Hot Reload reicht nach dem Hinzufügen des nativen Plugins nicht.
Der generierte iOS-Host bleibt lokal und Git-ignoriert. Bei einem CocoaPods-Hinweis
zuerst die konkrete Meldung prüfen; das Plugin dokumentiert Swift und
`use_frameworks!` im Runner-Target des Podfiles. Keine pauschalen Pod-/Lock-Resets.
Quelle: [printing installieren](https://pub.dev/packages/printing#installing).

## Demo-Abnahme im Simulator

1. Fiktiven Namen und zwei Karten reservieren (beim Bootstrap-Preis 90,00 EUR).
2. **PDF-Beleg öffnen**: richtige Referenz, Name, Menge, Einzel-/Gesamtpreis,
   Zahlungsfrist und Demo-Bankdaten prüfen.
3. **PDF teilen** öffnen, dann abbrechen. Tatsächliche Zustellung ist nicht Teil
   der Abnahme; die App behauptet keine Zustellung.
4. Zurück zur Bestätigung: keine zusätzliche Reservierung, unveränderte Einnahmen.
5. Beleg bei gestopptem Backend öffnen: Fehler und **Beleg erneut laden** müssen
   sichtbar sein. Erst Backend starten, dann erneut laden; nicht neu reservieren.

Der Token wird wie bisher einmal je App-Lauf in der Ticketansicht eingefügt.
Nach vollständigem App-Neustart ist auch die letzte Bestätigung nur lokal nicht
mehr vorhanden; die Buchung bleibt in der Datenbank. Für die Beleg-Abnahme eine
neue fiktive Reservierung verwenden. Die Übersicht aller Reservierungen folgt
in SDA-13.

## PDF-Inhalt und QR

- Alle Buchungsfelder kommen aus einer gemeinsamen SQL-Lese-Transaktion.
  Der Kartenpreis stammt aus der Reservierung, nicht aus dem aktuellen Angebot.
- Fristen werden mit der expliziten Zeitzone Europe/Berlin ausgegeben.
- ReportLab erzeugt PDF und QR lokal, inklusive eingebetteter Schrift. Es werden
  keine Online-Schriften, externen Bilder oder PDF-Dienste verwendet.
- Empfänger: **AppI Demo-Abikasse (fiktiv)**.
- IBAN: **DE00 0000 0000 0000 0000 00**, absichtlich ungültig. Nicht überweisen.
- Verwendungszweck ist die gespeicherte, opake Reservierungsreferenz.
- QR-Inhalt: `appi-demo://reservation/<Referenz>`. Es gibt noch keine hinterlegte
  App-/Website-Route. Der Link lässt sich in dieser Demo nicht öffnen.
- Der QR enthält weder Käufername noch Org-Token und darf keine Zahlung oder
  Eintrittsberechtigung bestätigen. Auch der PDF-Abruf bleibt Org-geschützt.
- Bezahlte/stornierte Reservierungen werden beim erneuten PDF-Abruf mit ihrem
  aktuellen Status und einem passenden Zahlungshinweis angezeigt. Es bleibt ein
  Reservierungsbeleg, keine Eintrittskarte.

## API

`GET /api/v1/reservations/{reference}/receipt.pdf`

Org-Header wie bei den Reservierungsendpunkten. Antwort `application/pdf`,
`Content-Disposition: inline`, `Cache-Control: no-store`; 401 ohne gültigen
Zugang, 404 bei unbekannter Referenz. Der Abruf verändert weder Kontingent noch
Ledger. Keine Zugangsdaten im Dateinamen, Dokument oder QR.

## Tests und durchgeführte Checks

Neue Backend-Tests prüfen PDF-Daten gegen gespeicherte Werte, Authentifizierung,
Status/Frist, lange Namen und fehlende Buchungsänderungen. Der QR wird aus der
wirklichen PDF-Seite gerendert und wieder eingelesen (lokale Test-Abhängigkeiten
`pypdfium2`, Pillow und `zxing-cpp`, kein Kamera-/Netzzugriff).
Flutter-Tests prüfen binären API-Abruf, ungültige PDF-Antworten, Navigation,
Ladefehler/Retry und die Übergabe derselben Bytes an Vorschau und Teilen.
Native PDF-Rasterisierung und das Teilen-Menü werden im Simulator abgenommen;
die Widget-Tests ersetzen nur diese Plattformgrenzen durch kontrollierte Fakes.

Die KI hat keine Tests, keinen Flutter-Analyzer und keinen Simulator-Build
ausgeführt. Python-/Shell-Syntax und `git diff --check` wurden geprüft; eine
fiktive PDF-Layoutvorschau wurde gerendert und visuell kontrolliert.

Führe keine Tests aus – diese müssen vollständig lokal über VS Code laufen.
