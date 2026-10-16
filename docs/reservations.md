# Kartenreservierung (SDA-11)

Die Kachel **Abiball-Tickets** führt zur echten lokalen Reservierung. Preis,
Frist und Kontingent werden aus dem Backend geladen. Beispieltermin und -ort
sind ausdrücklich fiktiv. Es gibt keine echten Zahlungen oder Buchungen.

## Lokal ausprobieren

1. Backend über die bestehende `.command` starten und geöffnet lassen.
2. App aus `app/` wie gewohnt mit `flutter run` im iOS-Simulator starten.
3. Für den ersten Verkauf den lokalen Demo-Token im Mac-Terminal kopieren:

   ```bash
   cd '/Users/christian/!PROJECT/school-demo-appi'
   pbcopy < backend/data/org-token
   ```

4. In **Abiball-Tickets → Lokaler Demo-Zugang** einfügen. Im Simulator bei Bedarf
   **Edit → Paste** nutzen. Der Token bleibt ausschließlich im Arbeitsspeicher
   bis zum App-Neustart. Hot Reload behält ihn normalerweise bei.
5. Einen fiktiven Namen und beispielsweise zwei Karten eingeben. Bei unverändertem
   Bootstrap-Preis erscheint **90,00 €**. Reservieren speichert im Backend.
6. Bestätigung zeigt gespeicherte Referenz, Anzahl, Betrag, Status und exakte Frist.
   **PDF-Beleg öffnen** öffnet den PDF-Beleg; **Reservierungsdaten öffnen**
   zeigt die kompakten Serverdaten in einer Übersicht. Einrichtung: [receipts.md](receipts.md).
7. Das Kontingent wird nach Erfolg erneut geladen: zwei zusätzliche Karten sind
   reserviert. Dashboard-Einnahmen ändern sich durch diese Reservierung nicht.

Falls das Backend bewusst mit eigenem `APPI_ORG_TOKEN` gestartet wurde, diesen
Wert verwenden; die Datei muss dann nicht dem laufenden Backend entsprechen.
Optional lässt sich der Token beim App-Start per `--dart-define=APPI_ORG_TOKEN=...`
übergeben. Keine echten Schlüssel in Launch-Konfigurationen oder Git speichern.

## Verhalten bei Fehlern

- Name: nach Trimmen 1–120 Zeichen; Menge: ganze Zahl von 1 bis 1000.
- Die Backend-Prüfung entscheidet über den tatsächlichen Restbestand.
  Bei einer eindeutigen Ablehnung bleiben Eingaben erhalten und können korrigiert
  werden; die Verfügbarkeit wird erneut geladen.
- Während des Speicherns ist der Button gesperrt. Jede neue Bestellung erhält eine
  zufällige UUID v4. Wiederholungen nutzen unverändert dieselbe UUID und Nutzlast.
- Bei unklarer Antwort (Netzfehler, Timeout, 5xx, unvollständige Erfolgsantwort)
  bleiben Name und Menge gesperrt. **Dieselbe Anfrage erneut senden** kann eine
  bereits gespeicherte Reservierung wiederfinden, ohne erneut Karten zu belegen.
  Eine nachfolgende Zugangsstörung hebt diese Sperre nicht auf.
- Zurück zum Dashboard und erneutes Öffnen behalten den offenen Vorgang für diesen
  App-Lauf bei. Noch keine dauerhafte lokale Wiederaufnahme nach App-Beendigung:
  bei unklarer Antwort zuerst erneut senden und die Bestätigung abwarten. Bereits
  gespeicherte Buchungen bleiben im Backend bestehen. Org-Liste folgt SDA-13.
- Scheitert die Aktualisierung der Verfügbarkeit, bleibt die gespeicherte
  Reservierung bestätigt; es wird kein veralteter Restbestand als aktuell gezeigt.

## Grenzen und nächste Schritte

SDA-12 ergänzt den tatsächlichen PDF-Beleg mit Demo-Zahlungsdaten, QR und Teilen.
Die Reservierungsübersicht bleibt daneben als kompakte Datenansicht erhalten.
Einrichtung und Abnahme des PDFs: [receipts.md](receipts.md).
SDA-13 ergänzt Zahlungseingang, Verlängerung und Storno in der Org-Ansicht.
PMG-Branding ist als spätere Änderung vorgemerkt; Card-Größen bleiben bewusst
für mögliche Schülerideen unverändert.

## Lokal über VS Code prüfen

Aus `app/`:

```bash
flutter analyze
flutter test
```

Neue Tests: Validierung, Doppel-Tap, unklare Antwort mit sicherem Retry,
Bestandskonflikt mit Eingabeerhalt, Bestätigung/Verfügbarkeits-Refresh und
HTTP-Vertrag inklusive Org-Header. HTTP-Tests verwenden einen eigenen lokalen
Testserver, keine laufende Demo-DB. Bestehende Backend-Tests sichern die
Transaktion, Bestandsprüfung und Idempotenz ab.

Führe keine Tests aus – diese müssen vollständig lokal über VS Code laufen.
Die KI hat weder Tests noch Flutter-Analyzer oder Simulator-Build ausgeführt.
