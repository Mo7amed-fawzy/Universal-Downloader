import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def archive_directory(directory, destination, prefix=''):
    with zipfile.ZipFile(destination, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for file in sorted(directory.rglob('*')):
            if file.is_file():
                output.write(file, prefix + file.relative_to(directory).as_posix())


def main():
    if sys.platform != 'win32' or platform.machine().lower() not in ['amd64', 'x86_64']:
        raise RuntimeError('Run this build on Windows x64 with Flutter and Visual Studio C++ tools')
    flutter = shutil.which('flutter')
    dart = shutil.which('dart')
    if not flutter or not dart:
        raise RuntimeError('Flutter and Dart must be on the developer PATH')
    subprocess.run([sys.executable, 'tool/prepare_tools.py', '--platform', 'windows-x64'], cwd=ROOT, check=True)
    subprocess.run([flutter, 'build', 'windows', '--release'], cwd=ROOT, check=True)
    bundle = ROOT / 'build/windows/x64/runner/Release'
    required = ['universal_downloader.exe', 'flutter_windows.dll', 'msvcp140.dll',
                'vcruntime140.dll', 'vcruntime140_1.dll', 'data/icudtl.dat', 'data/app.so']
    for name in required:
        if not (bundle / name).is_file():
            raise RuntimeError('Incomplete Windows package: ' + name)
    tools = bundle / 'tools'
    manifest = json.loads((tools / 'manifest.json').read_text())
    if manifest['platform'] != 'windows-x64' or not manifest.get('runtimeValidated'):
        raise RuntimeError('Windows tools have not been validated')
    actual = {p.relative_to(tools).as_posix() for p in tools.rglob('*') if p.is_file()}
    if actual != set(manifest['files']) | {'manifest.json'}:
        raise RuntimeError('Unexpected or missing tool files; remove the stale build/windows directory and rebuild')
    for name, expected in manifest['files'].items():
        with (tools / name).open('rb') as file:
            if hashlib.file_digest(file, 'sha256').hexdigest() != expected:
                raise RuntimeError('Bundled tool checksum mismatch: ' + name)
    smoke = ROOT / 'build/windows-runtime-smoke.exe'
    subprocess.run([dart, 'compile', 'exe', 'tool/smoke_runtime.dart', '-o', str(smoke)], cwd=ROOT, check=True)
    environment = dict(os.environ)
    system_root = Path(os.environ['SystemRoot'])
    environment['PATH'] = str(system_root / 'System32') + os.pathsep + str(system_root)
    subprocess.run([str(smoke), str(bundle)], cwd=ROOT, env=environment, check=True)
    destination = ROOT / 'dist'
    destination.mkdir(exist_ok=True)
    runtime_archive = destination / 'runtime-windows-x64.zip'
    archive_directory(tools, runtime_archive)
    with runtime_archive.open('rb') as file:
        runtime_hash = hashlib.file_digest(file, 'sha256').hexdigest()
    metadata = {'schema': 1, 'platform': 'windows-x64', 'revision': manifest['revision'], 'sha256': runtime_hash}
    (destination / 'runtime-windows-x64.json').write_text(json.dumps(metadata, indent=2) + '\n')
    app_archive = destination / 'universal-downloader-windows-x64.zip'
    archive_directory(bundle, app_archive, 'universal-downloader/')
    for file in [app_archive, runtime_archive]:
        with file.open('rb') as content:
            digest = hashlib.file_digest(content, 'sha256').hexdigest()
        file.with_suffix(file.suffix + '.sha256').write_text(digest + '  ' + file.name + '\n')
        print(file, file.stat().st_size, 'bytes', flush=True)


if __name__ == '__main__':
    main()
