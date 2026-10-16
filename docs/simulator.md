# AppI im iOS-Simulator (SDA-9)

## Stand

Flutter-Grundprojekt mit Splash, Startseite, Backend-Konfiguration und vier
navigierbaren Bereichen. Es gibt noch keinen Kartenverkauf in der Oberfläche und
noch keinen Fundraising-Balken. Diese Funktionen folgen in SDA-10 bis SDA-14.
Die Startseite stellt Demo-Inhalte dar, keine aktuellen Angebote der Schule.

Der Splash bleibt nur während des ersten Konfigurationsabrufs sichtbar, maximal
bis zum Netzwerk-Timeout. Keine künstliche Mindestdauer. Bei Fehlern zeigt die
Startseite einen Hinweis und Wiederholen; die Vorschau bleibt nutzbar.

Die Campusgrafik ist ein eigener geometrischer CustomPainter-Platzhalter in
`app/lib/widgets/school_artwork.dart`, keine Aufnahme oder Nachbildung des PMG.
Es werden keine fremden Schulbilder, Logos, Webfonts oder Laufzeit-Bilder geladen.
Sie kann später durch ein freigegebenes Schulbild ersetzt werden. Jahrgang und
Schulname: Defaults in `config.dart`, bei Verbindung aus Backend `/config`.
Die globale Lizenzfrage für das Projekt bleibt in SDA-17 zu klären.

## Start auf dem Mac

1. Backend über deinen bestehenden .command-Link starten und geöffnet lassen.
2. Im Finder `Start-AppI-Simulator.command` im Repository-Root doppelt anklicken.
3. Beim ersten Mal erzeugt der Starter den iOS-Host mit deinem vorhandenen
   Flutter-SDK in einem temporären Projekt und kopiert nur den iOS-Ordner.
   Der AppI-Quellcode wird nicht überschrieben. Danach lädt Flutter Abhängigkeiten
   und baut die App. Xcode und ein
   installierter iOS-Simulator sind erforderlich (wie bereits bei App-etit).
4. Sind mehrere Simulatoren geöffnet, im Terminal eine Nummer wählen. Physische
   iPhones werden vom Starter niemals als Ziel ausgewählt.
5. Im Flutter-Terminal löst **r** Hot Reload aus, **R** Hot Restart, **q** beendet
   den Flutter-Lauf. Backend bleibt unabhängig davon aktiv.

Bei `flutter nicht im PATH`: im VS-Code-Terminal `which flutter` prüfen. Den
vorhandenen Flutter-SDK-bin-Ordner in den Shell-PATH aufnehmen; der Starter
berücksichtigt zusätzlich die üblichen Homebrew-Pfade. Alternativ unten starten.

## VS Code / Terminal

Im Repository-Root:

```bash
cd app
python3 tool/prepare_ios.py
flutter pub get
python3 tool/run_simulator.py
```

Oder in VS Code die Konfiguration **AppI – iOS-Simulator** auswählen und zuvor
unten rechts ausdrücklich ein Simulator-Gerät wählen. In einem Multi-Root-
Workspace gehört diese Konfiguration zum Ordner `school-demo-appi`.

Das Backend verwendet auf dem Mac `127.0.0.1:8000`; der iOS-Simulator erreicht es
unter derselben Adresse. Andere Zieladresse über `APPI_API_BASE_URL` beim Starter
oder `--dart-define=APPI_API_BASE_URL=...` bei `flutter run`. Änderungen dieses
Wertes benötigen einen Neustart des Flutter-Laufs, keinen bloßen Hot Reload.

In SDA-9 wird nur die öffentliche Konfiguration geladen, kein Org-Token benötigt.
Der spätere Kartenworkflow erhält seinen Zugang separat. Keine Tokens in Git.
Lokales HTTP ist eine Demo-Ausnahme; für öffentliche Nutzung HTTPS vorsehen.

## Lokale Prüfungen

Über VS Code Tasks **AppI: Flutter analysieren** und **AppI: Flutter-Tests lokal**
oder im integrierten Terminal aus `app`:

```bash
flutter analyze
flutter test
```

Widget-Tests decken Start-/Ladezustand, Backend-Fehler, Navigation und schmale
Ansichten ab. Sie wurden durch die KI nicht ausgeführt. Die iOS-Laufzeitprüfung
und Hot-Reload-Abnahme müssen auf dem Mac erfolgen. Kein iPhone-Build erforderlich.

## Generierter iOS-Host und Verifikation

`app/ios/` wird lokal erzeugt und ist Git-ignoriert. Die Erzeugung erfolgt in
einem temporären Flutter-Projekt; vorhandener Dart-Code und pubspec bleiben
unberührt. Ein unvollständiger iOS-Ordner wird nicht automatisch überschrieben.
Der Starter setzt App-Anzeigename und die lokale Netzwerk-Ausnahme in Info.plist.
Eine spätere produktive iOS-Konfiguration ist ein eigener Schritt.

Auf dieser Arbeitsumgebung konnte die Flutter-SDK-Initialisierung wegen einer
automatisch abgelehnten Cloud-Metadaten-Anfrage nicht abgeschlossen werden.
Kein Flutter-Analyzer, kein Build und keine Widget-Tests wurden hier ausgeführt.
Dart-Dateien wurden formatiert; Shell-/Python-Syntax wurde geprüft.
