import hashlib
import json
import platform
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / '.tool-cache'
DESTINATION = ROOT / 'build/tool-runtime'


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
    if platform.system() != 'Linux' or platform.machine() != 'x86_64':
        raise RuntimeError('This package currently targets Linux x86_64 only')
    pins = json.loads((ROOT / 'tool/tool_versions.json').read_text())
    CACHE.mkdir(exist_ok=True)
    DESTINATION.parent.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=DESTINATION.parent, prefix='tool-staging-') as temporary:
        staging = Path(temporary)
        licenses = staging / 'licenses'
        licenses.mkdir()
        for name, source in pins['sources'].items():
            archive = CACHE / (source['sha256'] + '-' + source['url'].split('/')[-1])
            print('Preparing', name, source['version'], flush=True)
            download(source['url'], archive, source['sha256'])
            if name == 'yt-dlp':
                shutil.copy2(archive, staging / name)
            elif name == 'deno':
                with zipfile.ZipFile(archive) as contents:
                    (staging / name).write_bytes(contents.read('deno'))
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
        versions = {}
        for name in ['yt-dlp', 'ffmpeg', 'ffprobe', 'deno']:
            executable = staging / name
            executable.chmod(0o755)
            result = subprocess.run([str(executable), '-version' if name.startswith('ff') else '--version'],
                                    check=True, capture_output=True, text=True, timeout=30)
            versions[name] = result.stdout.splitlines()[0]
            print(versions[name], flush=True)
        manifest = {'schema': 1, 'platform': pins['platform'], 'revision': pins['revision'],
                    'versions': versions, 'sources': pins['sources'],
                    'files': {str(p.relative_to(staging)): hashlib.file_digest(p.open('rb'), 'sha256').hexdigest()
                              for p in sorted(staging.rglob('*')) if p.is_file()}}
        (staging / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
        if DESTINATION.exists():
            shutil.rmtree(DESTINATION)
        shutil.copytree(staging, DESTINATION)
    print('Prepared', DESTINATION)


if __name__ == '__main__':
    main()
