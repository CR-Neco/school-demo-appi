#!/bin/bash
# Explicit local reset; the Python command refuses a running backend and backs up the DB.
set -eu
PROJECT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
PYTHON="$PROJECT_DIR/backend/.venv/bin/python"
cd "$PROJECT_DIR/backend"
printf '\033]0;PMG AppI – Demo zurücksetzen\007'
printf '\nPMG AppI – vorbereiteten Demo-Stand wiederherstellen\n'
printf 'Bitte zuerst App beenden und Backend mit Ctrl+C stoppen.\n'
printf 'Die vorhandene Datenbank wird gesichert. Danach gelten wieder die Demo-Beispiele.\n'
printf 'Zum Zurücksetzen RESET eingeben (jede andere Eingabe bricht ab): '
read -r answer || exit 0
if [ "$answer" != 'RESET' ]; then
    printf 'Abgebrochen.\n'
    exit 0
fi
if [ ! -x "$PYTHON" ]; then
    printf 'Python-Umgebung fehlt. Bitte die Backend-Einrichtung durchführen.\n'
else
    "$PYTHON" -m appi.demo reset --confirm RESET || true
fi
printf '\nZum Schließen Enter drücken … '
read -r _ || true
