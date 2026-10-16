# SDA-10: Finanzierungsdashboard

PMG AppI zeigt oberhalb der Kacheln die Abikasse des konfigurierten Jahrgangs.
Die Daten stammen aus GET /api/v1/dashboard: bestätigte Ledger-Einnahmen minus
Ausgaben, ohne offene Reservierungen. Es werden keine zusätzlichen Einnahmen
oder Beispielzahlungen beim App-Start erzeugt. Eine frische Datenbank zeigt daher
0,00 EUR von 15.000,00 EUR. Reichhaltigere Seed-Daten folgen in SDA-8.

Die Oberfläche berechnet Prozent und Restbetrag aus den Cent-Summen. Der Balken
bleibt zwischen 0 und 100 Prozent, die tatsächliche Prozentzahl darf darüber
oder darunter liegen. Ein ungültiges Ziel wird erklärt, nie durch eine erfundene
Zahl ersetzt. Ein nicht geladener oder fehlgeschlagener Abruf zeigt keine Zahlen.

Aktualisierung: Button in der Finanzierungskarte, Rückkehr aus jeder Unterseite
und App-Lifecycle resumed. Kein periodischer Hintergrundverkehr. Die spätere
Org-Zahlungsansicht kehrt danach zur Startseite zurück oder verwendet denselben
Refresh-Callback. Ihr eigentlicher Zahlungsworkflow bleibt SDA-13. Eine externe
Zahlung bei dauerhaft offener Startseite wird über Aktualisieren geladen.
Konfigurations- und Finanzierungsfehler sind getrennt, die Kacheln bleiben nutzbar.

## Lokale Abnahme über VS Code

Im Ordner app:

```bash
flutter analyze
flutter test
flutter run
```

Backend-Tests im separaten integrierten Terminal mit aktivierter backend/.venv:

```bash
python -m pytest -q
```

Neue Tests wurden angelegt, nicht durch den KI-Agenten ausgeführt. Auch die
Simulator-Darstellung muss lokal geprüft werden. Keine Flutter-SDK-Initialisierung
in der Agenten-Umgebung vorgenommen.

Prüfen: Nullstand, Button Aktualisieren, Backend stoppen -> Fehlermeldung ohne
alte Summen, Backend neu starten -> Erneut versuchen, alle vier Kacheln und
Zurücknavigation. Beträge ändern sich nur durch tatsächlich gespeicherte
Ledger-Buchungen, nicht durch das Öffnen einer Kachel.
