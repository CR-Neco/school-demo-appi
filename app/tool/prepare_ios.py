#!/usr/bin/env python3
"""Generate the iOS host with the user's installed Flutter SDK, on macOS only.

The generated project lives in a temporary directory first, so flutter create
cannot overwrite AppI source, pubspec, tests or documentation.
"""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile

app_dir = Path(__file__).resolve().parents[1]
ios_dir = app_dir / 'ios'
if sys.platform != 'darwin':
    raise SystemExit('iOS-Projekt bitte lokal auf dem Mac vorbereiten.')
flutter = shutil.which('flutter')
if not flutter:
    raise SystemExit('Flutter nicht im PATH. Bitte im VS-Code-Terminal which flutter prüfen.')
if not (ios_dir / 'Runner.xcodeproj' / 'project.pbxproj').exists():
    if ios_dir.exists():
        raise SystemExit('Unvollständiger app/ios-Ordner vorhanden. Bitte prüfen, nicht automatisch überschreiben.')
    print('Einmalige Vorbereitung: iOS-Host aus deinem Flutter-SDK erzeugen.', flush=True)
    with tempfile.TemporaryDirectory(prefix='appi-ios-') as temporary:
        project = Path(temporary) / 'appi'
        subprocess.run([flutter, 'create', '--empty', '--platforms=ios',
                        '--project-name=appi', '--org=de.ruthke', '--no-pub', str(project)], check=True)
        shutil.copytree(project / 'ios', ios_dir)
        # This generated host is local, reproducible and intentionally Git-ignored.

plist_path = ios_dir / 'Runner' / 'Info.plist'
with plist_path.open('rb') as stream:
    config = plistlib.load(stream)
config['CFBundleDisplayName'] = 'PMG AppI'
config['NSLocalNetworkUsageDescription'] = 'Verbindung zum lokalen AppI-Demo-Backend und Flutter-Debugger.'
# Only local networking is allowed as a demo exception; no global arbitrary loads.
config.setdefault('NSAppTransportSecurity', {})['NSAllowsLocalNetworking'] = True
with plist_path.open('wb') as stream:
    plistlib.dump(config, stream, sort_keys=False)
print('iOS-Host vorbereitet. AppI-Quellcode bleibt unverändert.', flush=True)
