"""Local regression check: an existing iOS host receives the branded launch assets.

Run locally: python3 -m unittest discover -s tool/tests
No Flutter invocation, simulator, or native image conversion is needed here.
"""
import json
from pathlib import Path
import plistlib
import runpy
import shutil
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET


class PrepareIosTest(unittest.TestCase):
    def test_existing_host_gets_launch_storyboard_with_resolvable_images(self):
        source = Path(__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / 'app'
            shutil.copytree(source / 'tool', app / 'tool', ignore=shutil.ignore_patterns('__pycache__'))
            shutil.copytree(source / 'assets', app / 'assets')
            runner = app / 'ios' / 'Runner'
            runner.mkdir(parents=True)
            project = app / 'ios' / 'Runner.xcodeproj'
            project.mkdir()
            (project / 'project.pbxproj').write_text('existing host')
            with (runner / 'Info.plist').open('wb') as stream:
                plistlib.dump({'CFBundleDisplayName': 'old'}, stream)

            def convert(command, **kwargs):
                # Only the macOS image converter is substituted. Asset installation,
                # plist updates, and copying the storyboard run unchanged.
                self.assertEqual(command[0], '/usr/bin/sips')
                shutil.copyfile(command[4], command[6])

            with patch('sys.platform', 'darwin'), patch('shutil.which', return_value='/mock/flutter'), patch('subprocess.run', side_effect=convert):
                runpy.run_path(str(app / 'tool' / 'prepare_ios.py'), run_name='__main__')

            with (runner / 'Info.plist').open('rb') as stream:
                config = plistlib.load(stream)
            launch = runner / 'Base.lproj' / (config['UILaunchStoryboardName'] + '.storyboard')
            document = ET.parse(launch)
            image_names = {view.attrib['image'] for view in document.findall('.//imageView')}
            self.assertGreaterEqual(len(image_names), 2, 'Launch screen must not revert to blank white')
            self.assertTrue(any(label.attrib.get('text') == 'PMG AppI' for label in document.findall('.//label')))
            for name in image_names:
                catalog = runner / 'Assets.xcassets' / (name + '.imageset')
                manifest = json.loads((catalog / 'Contents.json').read_text())
                for image in manifest['images']:
                    self.assertTrue((catalog / image['filename']).is_file())
            self.assertEqual((project / 'project.pbxproj').read_text(), 'existing host')


if __name__ == '__main__':
    unittest.main()
