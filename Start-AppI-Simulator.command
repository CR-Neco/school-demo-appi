#!/bin/bash
set -eu
PROJECT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
# Finder-Terminals haben nicht immer den Homebrew-Pfad.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
fail() {
  printf '\n%s\nZum Schließen Enter drücken … ' "$1"
  read -r _ || true
  exit 1
}
[ "$(uname -s)" = Darwin ] || fail "Dieser Starter benötigt macOS und den iOS-Simulator."
command -v flutter >/dev/null 2>&1 || fail "Flutter nicht im PATH. Starte zunächst über VS Code: cd app && python3 tool/run_simulator.py"
command -v python3 >/dev/null 2>&1 || fail "Python 3 wird für die Simulator-Auswahl benötigt."
printf '\033]0;PMG AppI – Simulator\007'
printf '\nAppI-Simulator starten. Backend bitte separat geöffnet lassen.\n'
cd "$PROJECT_DIR/app"
python3 tool/prepare_ios.py || fail "iOS-Projekt konnte nicht vorbereitet werden."
flutter pub get || fail "Flutter-Abhängigkeiten konnten nicht vorbereitet werden."
python3 tool/run_simulator.py || fail "AppI konnte nicht gestartet werden. Bitte Meldung oben prüfen."
