#!/bin/bash
# macOS: Doppelklick im Finder startet ein eigenes Terminalfenster.
set -eu

PROJECT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
BACKEND_DIR="$PROJECT_DIR/backend"
PYTHON="$BACKEND_DIR/.venv/bin/python"

fail() {
    printf '\n%s\n' "$1"
    printf '\nZum Schließen Enter drücken … '
    read -r _ || true
    exit 1
}

cd "$BACKEND_DIR"
printf '\033]0;PMG AppI – Backend\007'
printf '\nPMG AppI – lokales Backend\n\n'

[ -x "$PYTHON" ] || fail "Python-Umgebung fehlt. Bitte zuerst die Einrichtung in README.md durchführen."
"$PYTHON" -c 'import uvicorn; from appi.main import app' >/dev/null 2>&1 || 
    fail "Backend-Abhängigkeiten fehlen. Im Ordner backend die .venv aktivieren und python -m pip install -e '.[dev]' ausführen."

# Festes lokales Ziel, passend zur Simulator-Demo; keinen bestehenden Prozess beenden.
"$PYTHON" - <<'PY' || fail "Port 8000 ist bereits belegt. Falls das Backend noch in VS Code läuft, dort mit Ctrl+C stoppen und diese Datei erneut öffnen."
import socket
with socket.socket() as connection:
    connection.bind(('127.0.0.1', 8000))
PY

# Ein stabiler lokaler Demo-Token erleichtert den späteren App-Start.
# Wird nicht angezeigt, liegt in backend/data/ und ist von Git ausgeschlossen.
# Ein bewusst gesetzter APPI_ORG_TOKEN hat Vorrang.
if [ -z "${APPI_ORG_TOKEN:-}" ]; then
    umask 077
    APPI_ORG_TOKEN="$("$PYTHON" - <<'PY'
from pathlib import Path
import secrets
path = Path('data/org-token')
path.parent.mkdir(parents=True, exist_ok=True)
try:
    with path.open('x') as file:
        file.write(secrets.token_urlsafe(32) + '\n')
except FileExistsError:
    pass
path.chmod(0o600)
token = path.read_text().strip()
if not token:
    raise SystemExit('Lokaler Demo-Token ist leer: backend/data/org-token prüfen.')
print(token)
PY
)" || fail "Der lokale Demo-Token konnte nicht vorbereitet werden."
fi
export APPI_ORG_TOKEN
export APPI_DB_PATH="${APPI_DB_PATH:-$BACKEND_DIR/data/appi.sqlite3}"

printf 'API:           http://127.0.0.1:8000/api/v1\n'
printf 'Health-Check:  http://127.0.0.1:8000/health\n'
printf 'API-Doku:      http://127.0.0.1:8000/docs\n\n'
printf 'Dieses Fenster während der AppI-Nutzung geöffnet lassen.\n'
printf 'Stoppen: Ctrl+C. VS Code kann unabhängig davon geöffnet/geschlossen werden.\n\n'

"$PYTHON" -m uvicorn appi.main:app --host 127.0.0.1 --port 8000 --reload || 
    fail "Backend wurde beendet. Bei einem Fehler bitte die Meldung oben prüfen."
