"""Exercise new frame metadata without changing the real asset directory."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

MOBILE = Path(__file__).resolve().parents[1]
SCRIPT = MOBILE / 'tool' / 'build_photobooth_catalog.py'
SOURCE = MOBILE / 'assets/photobooth/frames/classic/photo-strip-template-classic-2x6.png'


class FrameCatalogTests(unittest.TestCase):
    def setUp(self):
        workspace = MOBILE / 'build' / 'frame_catalog_tests'
        workspace.mkdir(parents=True, exist_ok=True)
        self.mobile = Path(tempfile.mkdtemp(dir=workspace))
        self.frame = self.mobile / 'assets/photobooth/frames/space/orbit.png'
        self.frame.parent.mkdir(parents=True)
        (self.mobile / 'assets/photobooth/stickers').mkdir()
        shutil.copy2(SOURCE, self.frame)
        self.pubspec = self.mobile / 'pubspec.yaml'
        self.pubspec.write_text('flutter:\n  assets:\n    - assets/images/scenery/icons/ui/\n', encoding='utf-8')
        self.meta = dict(key='orbit-portrait', theme='space', title='Orbit',
                         categoryTitle='Space', format='Portrait', slots=[
            dict(x=48, y=48 + i * 402, width=504, height=382, photo=i) for i in range(4)])

    def run_script(self):
        return subprocess.run([sys.executable, str(SCRIPT), '--mobile-root', str(self.mobile)],
                              capture_output=True, text=True, encoding='utf-8')

    def write_metadata(self):
        self.frame.with_suffix('.frame.json').write_text(json.dumps(self.meta), encoding='utf-8')

    def test_new_category_title_format_geometry_and_bundle_are_generated(self):
        self.write_metadata()
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads((self.mobile / 'assets/photobooth/catalog.json').read_text(encoding='utf-8'))
        frame = data['frames'][0]
        self.assertEqual((frame['key'], frame['title'], frame['theme'], frame['categoryTitle'], frame['format']),
                         ('orbit-portrait', 'Orbit', 'space', 'Space', 'Portrait'))
        self.assertEqual(frame['slots'], self.meta['slots'])
        self.assertIn('assets/photobooth/frames/space/orbit.png', self.pubspec.read_text())
        # Regeneration must not duplicate the asset section.
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.pubspec.read_text().count('frames/space/orbit.png'), 1)

    def test_unknown_frame_requires_measured_geometry(self):
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Add measured slot geometry', result.stderr)
        self.assertFalse((self.mobile / 'assets/photobooth/catalog.json').exists())

    def test_invalid_geometry_does_not_publish_a_catalog(self):
        self.meta['slots'][0]['width'] = 800
        self.write_metadata()
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Slot outside image', result.stderr)
        self.assertFalse((self.mobile / 'assets/photobooth/catalog.json').exists())

    def test_duplicate_keys_are_rejected(self):
        self.write_metadata()
        another = self.frame.with_name('second.png')
        shutil.copy2(SOURCE, another)
        another.with_suffix('.frame.json').write_text(json.dumps(self.meta), encoding='utf-8')
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Duplicate frame key', result.stderr)


if __name__ == '__main__':
    unittest.main()
