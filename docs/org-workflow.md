# Org-Team und Zahlungsbestätigung (SDA-13)

Die Kachel **Org-Team** öffnet die Reservierungsverwaltung. Der lokale Demo-Token
wird mit dem Kartenverkauf geteilt: Wer ihn dort bereits eingegeben hat, muss ihn
in diesem App-Lauf nicht erneut einfügen. Ansonsten den Zugang im aufklappbaren
Abschnitt eingeben und **Reservierungen laden** wählen.

## Lokale Aktualisierung

Flutter mit `q` beenden und das Backend mit Ctrl+C stoppen. Nach Checkout von
`feature/SDA-13-org-workflow` im Repository-Root:

```bash
backend/.venv/bin/python -m pytest -q backend/tests
cd app
flutter analyze
flutter test
```

Backend anschließend über die vorhandene `.command` starten und die App aus
`app/` mit `flutter run` starten. Es werden keine zusätzlichen Pakete eingeführt.
Die aus SDA-12 lokal aktualisierte `app/pubspec.lock` bleibt erhalten.

Beim ersten Backend-Start wird Schema 1 um eine Tabelle für wiederholbare
Verlängerungen zu Schema 2 ergänzt. Reservierungen und Ledger bleiben erhalten;
ein Datenbank-Reset ist dafür nicht erforderlich. Ältere Backend-Branches, die
nur Schema 1 unterstützen, können diese Datenbank danach nicht mehr öffnen.

## Kurzer Demo-Ablauf

1. Unter **Abiball-Tickets** für einen fiktiven Namen zwei Karten reservieren.
   Beim Bootstrap-Preis ergibt das 90,00 EUR. Den PDF-Beleg öffnen, dann zurück
   zum Dashboard. Die Abikasse hat durch die Reservierung noch keine Einnahme.
2. **Org-Team** öffnen und dieselbe Reservierung in der Liste auswählen oder
   die vollständige Referenz im Feld **Reservierungsnummer** einfügen und öffnen.
3. Name, Anzahl, Betrag, Status und Frist sind sichtbar. **Zahlung bestätigen**
   öffnet eine Nachfrage: Ist der vollständige Betrag auf dem Konto eingegangen?
   Die Demo hat keine Bankanbindung. **Abbrechen** verändert nichts.
4. **Bestätigen** speichert die manuelle Zahlungsbestätigung im Backend. Erst
   dessen Erfolgsantwort zeigt **Bezahlt**. Zurück über Liste zum Dashboard:
   Der Finanzierungsstand steigt um 90,00 EUR, der verfügbare Kartenbestand sinkt
   durch diese Zahlung kein zweites Mal. Bezahlte Karten bleiben im Kontingent.
5. Für Verlängerung/Storno eine weitere offene Reservierung nutzen.
   **Um 3 Tage verlängern** verschiebt die Frist ab dem späteren Zeitpunkt von
   jetzt und bisherigem Ablauf. **Reservierung stornieren** gibt die Karten frei.
   Beide Aktionen benötigen eine Bestätigung; bezahlte/stornierte Fälle bieten
   diese Aktionen nicht mehr an.
6. Der PDF-Beleg ist auch in der Org-Detailansicht erreichbar und wird beim Öffnen
   frisch mit aktuellem Status/Frist aus dem Backend geladen.

## Status und Fehler

- Offen: **Reserviert - noch nicht bezahlt**.
- Überfällig: **Überfällig - weiter reserviert** plus Erklärung. Eine abgelaufene
  Frist gibt keine Karten automatisch frei; das Org-Team entscheidet bewusst.
- Bezahlt bzw. Storniert sind Endzustände dieser Demo. Es gibt keine Erstattung
  und keine nachträgliche Änderung des Kartenpreises in dieser Ansicht.
- Keine optimistischen Statuswechsel: Während einer Änderung ist der letzte
  bestätigte Stand markiert, alle weiteren Schreibaktionen sind gesperrt.
- Bei unklarer Antwort bleibt die beabsichtigte Aktion je Reservierung in der
  App-Sitzung erhalten. **Dieselbe Änderung erneut senden** fordert erneut eine
  Bestätigung an und wiederholt dieselbe logische Aktion.
- Zahlung und Storno waren bereits im Backend wiederholbar. Verlängerungen
  erhalten zusätzlich eine UUID und werden innerhalb derselben SQL-Transaktion
  mit der Friständerung protokolliert. Dieselbe UUID mit denselben Daten gibt
  den aktuellen Datensatz zurück; andere Daten mit derselben UUID ergeben 409.
- Nach eindeutigem Konflikt bleibt die Fehlermeldung sichtbar; zuerst
  **Aktuellen Stand laden**, dann die aktuelle Situation beurteilen.
- Beim Navigieren zurück zur Liste bleiben unklare Aktionen je Referenz erhalten.
  Während einer laufenden Schreibanfrage ist Zurücknavigation gesperrt. Nach
  vollständigem App-Neustart sind diese lokalen Sitzungen nicht wiederherstellbar;
  die Buchungen und Verlängerungsreferenzen bleiben im Backend bestehen.

## Lokale Tests

Neue Backend-Tests decken Verlängerungs-Retry, geänderte Nutzlast/Referenz,
Backend-Neustart und datenerhaltende Schema-1-Migration ab. Die bisherigen Tests
prüfen Zahlung genau einmal, Ledger/Bestand, Storno und überfällige Fälle.
Neue Flutter-Tests prüfen Org-HTTP-Vertrag, Bestätigen/Abbrechen, verzögerten
Backend-Erfolg, Statusanzeige, unklare Änderungen, Eingabe einer Referenz,
Ladefehler und den Dashboard-Refresh nach Zahlung ohne App-Neustart.

Die KI hat keine Tests, keinen Flutter-Analyzer und keinen Simulator-Build
ausgeführt. Python-Syntax und `git diff --check` wurden geprüft. Die lokale
Abnahme erfolgt vollständig in VS Code und im iOS-Simulator.

Führe keine Tests aus – diese müssen vollständig lokal über VS Code laufen.

Such-/Filterkomfort bleibt als mögliche Schüleridee offen. PMG-Branding ist für
einen späteren Schritt vorgemerkt; Card-Größen werden nicht angeglichen.
