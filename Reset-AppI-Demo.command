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
reset_status=0
if [ ! -x "$PYTHON" ]; then
    printf 'Python-Umgebung fehlt. Bitte die Backend-Einrichtung durchführen.\n'
    reset_status=1
else
    if "$PYTHON" -m appi.demo reset --scenario demo --confirm RESET; then
        printf '\nReset bestätigt. Bitte Backend und App vollständig neu starten.\n'
    else
        reset_status=$?
        printf '\nRESET NICHT BESTÄTIGT. Bitte die Fehlermeldung oben prüfen.\n'
    fi
fi
printf '\nZum Schließen Enter drücken … '
read -r _ || true

exit "$reset_status"
