import argparse
import hashlib
import sys
import json
import platform
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request
import zipfile
from pathlib import Path

from windows_runtime import copy_visual_cpp_runtime


ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / '.tool-cache'


def download(url, destination, expected=None):
    if destination.exists() and expected:
        if hashlib.file_digest(destination.open('rb'), 'sha256').hexdigest() == expected:
            return
    request = urllib.request.Request(url, headers={'User-Agent': 'UniversalDownloader-build'})
    temporary = destination.with_suffix(destination.suffix + '.part')
    with urllib.request.urlopen(request, timeout=60) as response, temporary.open('wb') as output:
        shutil.copyfileobj(response, output)
    if expected and hashlib.file_digest(temporary.open('rb'), 'sha256').hexdigest() != expected:
        temporary.unlink()
        raise RuntimeError('Checksum mismatch: ' + url)
    temporary.replace(destination)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--platform', choices=['linux-x64', 'windows-x64'],
                        default='windows-x64' if sys.platform == 'win32' else 'linux-x64')
    parser.add_argument('--skip-execution', action='store_true')
    args = parser.parse_args()
    windows = args.platform == 'windows-x64'
    native = (sys.platform == ('win32' if windows else 'linux') and
              platform.machine().lower() in ['amd64', 'x86_64'])
    if not native and not args.skip_execution:
        raise RuntimeError('Build on the target OS, or use --skip-execution for inspection only')
    destination = ROOT / ('build/tool-runtime-windows' if windows else 'build/tool-runtime')
    pins = json.loads((ROOT / ('tool/tool_versions_windows.json' if windows else 'tool/tool_versions.json')).read_text())
    CACHE.mkdir(exist_ok=True)
    destination.parent.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=destination.parent, prefix='tool-staging-') as temporary:
        staging = Path(temporary)
        licenses = staging / 'licenses'
        licenses.mkdir()
        for name, source in pins['sources'].items():
            archive = CACHE / (source['sha256'] + '-' + source['url'].split('/')[-1])
            print('Preparing', name, source['version'], flush=True)
            download(source['url'], archive, source['sha256'])
            if name == 'yt-dlp':
                shutil.copy2(archive, staging / (name + ('.exe' if windows else '')))
            elif name == 'deno':
                with zipfile.ZipFile(archive) as contents:
                    executable = 'deno.exe' if windows else 'deno'
                    (staging / executable).write_bytes(contents.read(executable))
            elif windows:
                with zipfile.ZipFile(archive) as contents:
                    for member in contents.infolist():
                        if member.is_dir():
                            continue
                        relative = Path(member.filename)
                        if '..' in relative.parts or relative.is_absolute() or ':' in member.filename or '\\' in member.filename:
                            raise RuntimeError('Unsafe runtime archive path')
                        if relative.parent.name == 'bin' and relative.name in ['ffmpeg.exe', 'ffprobe.exe']:
                            target = staging / relative.name
                        elif any(part.lower() in ['licenses', 'doc'] for part in relative.parts):
                            target = licenses / 'ffmpeg' / Path(*relative.parts[1:])
                        elif relative.name.lower().startswith(('license', 'copying', 'readme')):
                            target = licenses / 'ffmpeg' / relative.name
                        else:
                            continue
                        target.parent.mkdir(parents=True, exist_ok=True)
                        with contents.open(member) as input_file, target.open('wb') as output:
                            shutil.copyfileobj(input_file, output)
            else:
                with tarfile.open(archive) as contents:
                    for member in contents.getmembers():
                        if not member.isfile():
                            continue
                        relative = Path(member.name)
                        if relative.name in ['ffmpeg', 'ffprobe'] and relative.parent.name == 'bin':
                            target = staging / relative.name
                        elif any(part.lower() in ['licenses', 'doc'] for part in relative.parts):
                            target = licenses / 'ffmpeg' / Path(*relative.parts[1:])
                        elif relative.name.lower().startswith(('license', 'copying', 'readme')):
                            target = licenses / 'ffmpeg' / relative.name
                        else:
                            continue
                        target.parent.mkdir(parents=True, exist_ok=True)
                        with contents.extractfile(member) as input_file, target.open('wb') as output:
                            shutil.copyfileobj(input_file, output)
        notices = {
            'yt-dlp-LICENSE': 'https://raw.githubusercontent.com/yt-dlp/yt-dlp/' + pins['sources']['yt-dlp']['version'] + '/LICENSE',
            'yt-dlp-THIRD_PARTY_LICENSES.txt': 'https://raw.githubusercontent.com/yt-dlp/yt-dlp/' + pins['sources']['yt-dlp']['version'] + '/THIRD_PARTY_LICENSES.txt',
            'deno-LICENSE.md': 'https://raw.githubusercontent.com/denoland/deno/' + pins['sources']['deno']['version'] + '/LICENSE.md',
        }
        for name, url in notices.items():
            download(url, licenses / name)
        shutil.copy2(ROOT / 'tool/THIRD_PARTY_NOTICES.md', licenses / 'THIRD_PARTY_NOTICES.md')
        if windows and not args.skip_execution:
            copy_visual_cpp_runtime(staging)
        versions = {}
        for name in ['yt-dlp', 'ffmpeg', 'ffprobe', 'deno']:
            executable = staging / (name + ('.exe' if windows else ''))
            if not executable.is_file():
                raise RuntimeError('Missing executable: ' + str(executable))
            if args.skip_execution:
                versions[name] = 'Not executed; pinned source ' + pins['sources']['ffmpeg' if name == 'ffprobe' else name]['version']
                continue
            executable.chmod(0o755)
            result = subprocess.run([str(executable), '-version' if name.startswith('ff') else '--version'],
                                    check=True, capture_output=True, text=True, timeout=30)
            versions[name] = result.stdout.splitlines()[0]
            print(versions[name], flush=True)
        manifest = {'schema': 1, 'platform': pins['platform'], 'revision': pins['revision'],
                    'versions': versions, 'sources': pins['sources'], 'runtimeValidated': not args.skip_execution,
                    'files': {p.relative_to(staging).as_posix(): hashlib.file_digest(p.open('rb'), 'sha256').hexdigest()
                              for p in sorted(staging.rglob('*')) if p.is_file()}}
        (staging / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(staging, destination)
    print('Prepared', destination)


if __name__ == '__main__':
    main()
