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
def ios_simulators():
    result = subprocess.run([flutter, 'devices', '--machine'], capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(result.stderr or result.stdout)
    try:
        return [device for device in json.loads(result.stdout)
                if device.get('emulator') and device.get('targetPlatform') == 'ios']
    except json.JSONDecodeError:
        raise SystemExit('Flutter-Geräteliste konnte nicht gelesen werden. Bitte flutter devices prüfen.')

# Prefer an already booted simulator. Opening an app is unnecessary in this case.
devices = ios_simulators()
if not devices:
    selected = subprocess.run(['xcode-select', '-p'], capture_output=True, text=True)
    roots = []
    if os.environ.get('DEVELOPER_DIR'):
        roots.append(Path(os.environ['DEVELOPER_DIR']))
    if selected.returncode == 0:
        roots.append(Path(selected.stdout.strip()))
    roots.extend(app / 'Contents' / 'Developer' for app in Path('/Applications').glob('Xcode*.app'))
    candidates = []
    for root in roots:
        if root.suffix == '.app':
            root = root / 'Contents' / 'Developer'
        candidates.append(root / 'Applications' / 'Simulator.app')
    simulator = next((path for path in candidates if path.is_dir()), None)
    command = ['open', str(simulator)] if simulator else ['open', '-a', 'Simulator']
    launch = subprocess.run(command, capture_output=True, text=True)
    if launch.returncode != 0:
        print('Simulator bitte in Xcode über Open Developer Tool > Simulator öffnen.', flush=True)
    for _ in range(20):
        devices = ios_simulators()
        if devices:
            break
        time.sleep(1)
    if not devices:
        raise SystemExit('Kein gestarteter iOS-Simulator gefunden. Im Simulator ein iPhone öffnen und erneut starten. Falls es bereits läuft: Ausgabe von flutter devices und xcode-select -p prüfen.')
else:
    print('Bereits gestarteten iOS-Simulator gefunden.', flush=True)

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
