"""Build a project-local Flutter Web SDK with flutter/flutter#194020.

The installed SDK is read only. Both debug JS and release kernel files must be
rebuilt: modifying window.dart alone does not change Flutter's cached engine.
"""

import argparse
import json
from pathlib import Path
import shutil
import subprocess


OLD = """    if (_shouldPreservePhysicalSizeOnResize && !_isRotation(newPhysicalSize)) {
      _computeOnScreenKeyboardInsets(true);
    } else {
      _physicalSize = newPhysicalSize;
      // When physical size changes this value has to be recalculated.
      _computeOnScreenKeyboardInsets(false);
    }"""
NEW = """    final bool isEditingOnMobile =
        _shouldPreservePhysicalSizeOnResize && !_isRotation(newPhysicalSize);
    if (!isEditingOnMobile || newPhysicalSize.height > physicalSize.height) {
      _physicalSize = newPhysicalSize;
    }
    _computeOnScreenKeyboardInsets(isEditingOnMobile);"""


def prepare(flutter_root: Path) -> Path:
    mobile = Path(__file__).resolve().parents[1]
    variant = mobile / '.dart_tool/web_engine/src/out/keyboard_fix'
    source = flutter_root / 'bin/cache/flutter_web_sdk'
    sdk = flutter_root / 'bin/cache/dart-sdk'
    output = variant / 'flutter_web_sdk'
    engine_file = Path('lib/_engine/engine/window.dart')
    content = (source / engine_file).read_text(encoding='utf-8')
    revision = (flutter_root / 'bin/cache/engine.stamp').read_text().strip()
    marker = variant / 'keyboard_fix.json'
    signature = {'engine': revision, 'patch': 2, 'flutter': str(flutter_root)}
    ready = marker.exists() and json.loads(marker.read_text()) == signature
    # Flutter's --local-web-sdk resolves the Dart toolchain in this layout.
    prebuilt = variant.parents[1] / 'flutter/prebuilts/windows-x64/dart-sdk'
    if not ready or not (prebuilt / 'bin/dart.exe').exists():
        print('Preparing the project-local Dart toolchain...', flush=True)
        shutil.copytree(sdk, prebuilt, dirs_exist_ok=True)
    if ready:
        print(f'Web SDK ready: {variant}', flush=True)
        return variant
    if OLD not in content and NEW not in content:
        raise RuntimeError('Unrecognized engine resize handler; review upstream fix before building.')
    output.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, output, dirs_exist_ok=True)
    (output / engine_file).write_text(content.replace(OLD, NEW), encoding='utf-8')
    libraries = json.loads((output / 'libraries.json').read_text())
    for target in libraries.values():
        if isinstance(target, dict):
            for include in target.get('include', []):
                include['path'] = (sdk / 'lib/libraries.json').as_uri()
    (output / 'libraries.json').write_text(json.dumps(libraries, indent=2))
    runtime = sdk / 'bin/dartaotruntime.exe'
    snapshots = sdk / 'bin/snapshots'
    common = [
        '--multi-root-scheme', 'org-dartlang-sdk',
        '--multi-root', output.as_uri() + '/',
        '--multi-root', (flutter_root / 'bin/cache').as_uri() + '/',
        '--libraries-file', (output / 'libraries.json').as_uri(),
    ]
    sources = ['dart:core', 'dart:ui', 'dart:ui_web', 'dart:_engine',
               'dart:_web_locale_keymap']
    for target, kernel in [('dart2js', 'dart2js_platform.dill'),
                           ('dart2wasm', 'dart2wasm_platform.dill')]:
        args = [str(runtime), str(snapshots / 'kernel_worker_aot.dart.snapshot'),
                '--target', target, '--no-summary-only', '--null-environment', *common,
                '--output', str(output / 'kernel' / kernel)]
        for library in sources + ['dart:_skwasm_impl' if target == 'dart2wasm' else 'dart:_skwasm_stub']:
            args += ['--source', library]
        print(f'Building {target} engine...', flush=True)
        subprocess.run(args, check=True)
    for module, folder in [('amd', 'amd-canvaskit'), ('ddc', 'ddclibrarybundle-canvaskit')]:
        args = [str(runtime), str(snapshots / 'dartdevc_aot.dart.snapshot'),
                '--compile-sdk', *sources, 'dart:_skwasm_stub', '--no-summarize',
                *common, '-DFLUTTER_WEB_USE_SKIA=true', '--modules', module,
                '--inline-source-map', '-o', str(output / 'kernel' / folder / 'dart_sdk.js')]
        if module == 'ddc':
            args += ['--canary']
        print(f'Building {module} debug engine...', flush=True)
        subprocess.run(args, check=True)
    marker.write_text(json.dumps(signature, indent=2))
    print(f'Web SDK ready: {variant}', flush=True)
    return variant


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter-root', type=Path)
    options = parser.parse_args()
    executable = shutil.which('flutter')
    root = options.flutter_root or (Path(executable).resolve().parents[1] if executable else None)
    if root is None:
        parser.error('Flutter is not on PATH; supply --flutter-root.')
    prepare(root.resolve())
