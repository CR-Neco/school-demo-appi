# PMG-Branding (SDA-19)

Die Bildkachel auf der Startseite verwendet das tatsächliche Schulbild. Die
anderen Kacheln behalten ihre vorhandenen Größen als mögliche Live-Änderungen.
Der Splash zeigt das originale PMG-Logo, PMG AppI und fiktive Schüler im Hintergrund.
Er bleibt wie bisher nur bis zum ersten Konfigurationsabruf sichtbar. Keine
künstliche Mindestdauer und keine Änderung am Backend oder an den Demo-Daten.

## Assets und Herkunft

Alle Dateien liegen unter `app/assets/branding/` und werden ohne Netzwerk gebündelt:

| Datei | Verwendung / Herkunft |
| --- | --- |
| `pmg-logo.png` | Unverändertes Original `Logo-PMG-2018-600x163.png`, vom Nutzer von der PMG-Website bereitgestellt |
| `pmg-campus.jpg` | Unverändertes Schulbild `Neu-3.jpg`, vom Nutzer von der PMG-Website bereitgestellt |
| `app-icon.png` | Generierte Icon-Adaption mit PMG-Schriftzug, Farbsymbol und Abschluss-Hut, aus dem bereitgestellten Logo abgeleitet; 1024 × 1024, RGB ohne Transparenz |
| `splash-students.jpg` | Generierte Illustration ausschließlich fiktiver Schüler; 960 × 1440, für die App komprimiert |

Quelle der beiden bereitgestellten Originale: https://pmg-meine.de/.
Das Icon ist eine Demo-Adaption, kein Ersatz für das offizielle Schullogo.
Die übergreifende Lizenz-/Übergabedokumentation bleibt in SDA-17.

## Lokal übernehmen

Flutter zuerst mit `q` beenden. Aus `app`:

```bash
flutter pub get
python3 tool/prepare_ios.py
flutter analyze
flutter test
flutter run
```

Der Python-Schritt aktualisiert auch bereits vorhandene lokale iOS-Hosts. Er nutzt
das mit macOS gelieferte `sips` und benötigt keine zusätzliche Python-Bibliothek.
Der `.command`-Starter führt die iOS-Vorbereitung ebenfalls aus. `app/ios/` bleibt
lokal generiert und Git-ignoriert. Für das native Icon ist ein neuer Flutter-Lauf
erforderlich; Hot Reload genügt nicht. Das Backend kann weiterlaufen.

Zusätzliche Widget-Tests prüfen das Splash-Layout bei schmalem Display und großer
Schrift sowie die Dekodierbarkeit der gebündelten Assets. Tests, Analyzer und
iOS-Build werden ausschließlich lokal ausgeführt; durch die KI nicht ausgeführt.
Python-Syntax und Git-Diff wurden geprüft.

## Generierung

Erstellt mit dem integrierten Imagegen-Werkzeug, jeweils als separates Bild.
Nur Größen-/Formatanpassung der generierten Bilder für die Asset-Auslieferung;
die Originale der Schule wurden unverändert kopiert. Das Original-Logo wird auf
dem Splash als eigene Ebene eingeblendet, nicht als Teil des generierten Motivs.

Icon-Prompt (Edit mit dem bereitgestellten Logo als Referenz):

> Create one polished square iOS app icon for PMG AppI using the supplied school logo as the exact visual reference. Opaque white background, edge-to-edge square without baked-in rounded corners, no mockup. Retain the recognizable purple PMG lettering and the four-color arrow/cross emblem (magenta, yellow, lime, cyan). Enlarge and simplify these central brand elements for readability at small icon sizes; omit the tiny school-name subtitle and divider. Add a tasteful dark purple graduation cap with a small gold tassel in the foreground toward the upper right, without hiding the PMG lettering. Flat crisp graphic design, restrained, faithful colors, balanced generous margins, no year, no other text. Output a single 1024 square icon.

Splash-Prompt (neues Bild ohne Fotoreferenz):

> Create a portrait background illustration for a German school graduation fundraising app splash screen. A few entirely fictional older students aged 18–19, diverse group of five, friendly relaxed conversation in a bright school courtyard, casual everyday clothing and backpacks, no graduation robes. Refined soft editorial illustration with believable proportions, warm off-white background, muted lavender, sage, pale cyan, subtle golden accents echoing a school identity. People clustered in the lower half and along edges, upper half mostly airy pale cream sky and subtle architecture, plenty of empty calm space for an app logo and title which will be overlaid later. Restrained simple composition, light and welcoming, no text, no logos, no watermarks. Portrait aspect ratio about 2:3.
