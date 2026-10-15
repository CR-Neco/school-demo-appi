#!/usr/bin/env python3
"""Generate the iOS host with the user's installed Flutter SDK, on macOS only.

The generated project lives in a temporary directory first, so flutter create
cannot overwrite AppI source, pubspec, tests or documentation.
"""
import os
import json
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

# The native host is ignored by Git. Reapply the versioned icon on every run,
# including hosts that were generated before the PMG branding was introduced.
# sips ships with macOS, so no Pillow or additional Python environment is needed.
icon_source = app_dir / 'assets' / 'branding' / 'app-icon.png'
icon_dir = ios_dir / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset'
icon_dir.mkdir(parents=True, exist_ok=True)
images = []
for idiom, sizes in (
    ('iphone', [('20', [2, 3]), ('29', [2, 3]), ('40', [2, 3]), ('60', [2, 3])]),
    ('ipad', [('20', [1, 2]), ('29', [1, 2]), ('40', [1, 2]), ('76', [1, 2]), ('83.5', [2])]),
    ('ios-marketing', [('1024', [1])]),
):
    for size, scales in sizes:
        for scale in scales:
            pixels = str(round(float(size) * scale))
            filename = f'PMG-{idiom}-{size}@{scale}x.png'
            destination = icon_dir / filename
            if pixels == '1024':
                shutil.copyfile(icon_source, destination)
            else:
                subprocess.run(['/usr/bin/sips', '-z', pixels, pixels,
                                str(icon_source), '--out', str(destination)],
                               check=True, stdout=subprocess.DEVNULL)
            images.append({'idiom': idiom, 'size': f'{size}x{size}',
                           'scale': f'{scale}x', 'filename': filename})
(icon_dir / 'Contents.json').write_text(
    json.dumps({'images': images, 'info': {'version': 1, 'author': 'xcode'}}, indent=2) + '\n'
)
print('iOS-Host und PMG-App-Icon vorbereitet. AppI-Quellcode bleibt unverändert.', flush=True)
