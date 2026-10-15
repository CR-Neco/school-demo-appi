#!/usr/bin/env python3
"""Select only an iOS simulator, never a connected physical phone."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

app_dir = Path(__file__).resolve().parents[1]
flutter = shutil.which('flutter')
if not flutter:
    raise SystemExit('flutter nicht im PATH. Bitte aus dem VS-Code-Terminal starten oder Flutter-Pfad einrichten.')

if not (app_dir / 'ios' / 'Runner.xcodeproj').exists():
    raise SystemExit('Bitte zuerst python3 tool/prepare_ios.py und flutter pub get ausführen.')
subprocess.run(['open', '-a', 'Simulator'], check=True)
for _ in range(20):
    result = subprocess.run([flutter, 'devices', '--machine'], capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(result.stderr or result.stdout)
    try:
        devices = [d for d in json.loads(result.stdout)
                   if d.get('emulator') and d.get('targetPlatform') == 'ios']
    except json.JSONDecodeError:
        raise SystemExit('Flutter-Geräteliste konnte nicht gelesen werden. Bitte flutter devices prüfen.')
    if devices:
        break
    time.sleep(1)
else:
    raise SystemExit('Kein gestarteter iOS-Simulator gefunden. Im Simulator über Datei > Simulator öffnen ein Gerät wählen und erneut starten.')

requested = os.environ.get('APPI_SIMULATOR_ID')
if requested:
    devices = [d for d in devices if d['id'] == requested]
    if not devices:
        raise SystemExit('APPI_SIMULATOR_ID passt zu keinem gestarteten iOS-Simulator.')
elif len(devices) > 1:
    print('Mehrere Simulatoren sind geöffnet:')
    for number, device in enumerate(devices, 1):
        print(f"{number}: {device['name']}")
    try:
        choice = int(input('Nummer wählen: '))
        if not 1 <= choice <= len(devices):
            raise ValueError()
        devices = [devices[choice - 1]]
    except (ValueError, EOFError):
        raise SystemExit('Keine gültige Simulator-Auswahl.')

base = os.environ.get('APPI_API_BASE_URL', 'http://127.0.0.1:8000/api/v1')
print(f"Starte AppI auf {devices[0]['name']}. Hot Reload: r · Beenden: q", flush=True)
os.chdir(app_dir)
os.execv(flutter, [flutter, 'run', '-d', devices[0]['id'], f'--dart-define=APPI_API_BASE_URL={base}'])
