import hashlib
import json
import subprocess
import tarfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def main():
    subprocess.run(['python3', 'tool/prepare_tools.py'], cwd=ROOT, check=True)
    subprocess.run(['flutter', 'build', 'linux', '--release'], cwd=ROOT, check=True)
    bundle = ROOT / 'build/linux/x64/release/bundle'
    tools = bundle / 'tools'
    manifest = json.loads((tools / 'manifest.json').read_text())
    destination = ROOT / 'dist'
    destination.mkdir(exist_ok=True)
    archive = destination / 'runtime-linux-x64.zip'
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for file in sorted(tools.rglob('*')):
            if file.is_file():
                output.write(file, file.relative_to(tools))
    metadata = {'schema': 1, 'platform': manifest['platform'], 'revision': manifest['revision'],
                'sha256': hashlib.file_digest(archive.open('rb'), 'sha256').hexdigest()}
    (destination / 'runtime-linux-x64.json').write_text(json.dumps(metadata, indent=2) + '\n')
    app_archive = destination / 'universal-downloader-linux-x64.tar.gz'
    with tarfile.open(app_archive, 'w:gz') as output:
        output.add(bundle, arcname='universal-downloader')
    for file in [app_archive, archive]:
        digest = hashlib.file_digest(file.open('rb'), 'sha256').hexdigest()
        file.with_suffix(file.suffix + '.sha256').write_text(digest + '  ' + file.name + '\n')
        print(file, file.stat().st_size, 'bytes', flush=True)


if __name__ == '__main__':
    main()
