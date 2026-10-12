import os
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

from build_windows import archive_directory
from windows_runtime import copy_visual_cpp_runtime


class WindowsPackagingTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='windows package ')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def test_app_archive_preserves_the_complete_folder(self):
        source = self.root / 'release'
        names = ['universal_downloader.exe', 'flutter_windows.dll',
                 'data/flutter_assets/العربية.txt', 'tools/ffmpeg.exe',
                 'tools/licenses/THIRD_PARTY_NOTICES.md', 'vcruntime140.dll']
        for name in names:
            file = source / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_bytes(name.encode('utf-8'))
        destination = self.root / 'app.zip'
        archive_directory(source, destination, 'universal-downloader/')
        with zipfile.ZipFile(destination) as archive:
            self.assertEqual(set(archive.namelist()), {'universal-downloader/' + n for n in names})
            for name in names:
                self.assertEqual(archive.read('universal-downloader/' + name), name.encode('utf-8'))

    def test_runtime_archive_has_no_extra_top_level_directory(self):
        source = self.root / 'tools'
        source.mkdir()
        (source / 'manifest.json').write_text('{}')
        (source / 'yt-dlp.exe').write_bytes(b'fixture')
        destination = self.root / 'runtime.zip'
        archive_directory(source, destination)
        with zipfile.ZipFile(destination) as archive:
            self.assertEqual(set(archive.namelist()), {'manifest.json', 'yt-dlp.exe'})

    def test_copies_release_crt_from_visual_studio_including_auxiliary_dlls(self):
        redist = self.root / 'Visual Studio/VC/Redist'
        crt = redist / 'x64/Microsoft.VC143.CRT'
        crt.mkdir(parents=True)
        names = ['msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'msvcp140_2.dll']
        for name in names:
            (crt / name).write_bytes(b'release-runtime')
        debug = redist / 'debug_nonredist/x64/Microsoft.VC143.DebugCRT'
        debug.mkdir(parents=True)
        (debug / 'vcruntime140d.dll').write_bytes(b'debug-runtime')
        output = self.root / 'tools'
        output.mkdir()
        with patch.dict(os.environ, {'VCToolsRedistDir': str(redist)}):
            copy_visual_cpp_runtime(output)
        self.assertEqual({p.name for p in output.iterdir()}, set(names))

    def test_incomplete_crt_fails_preparation(self):
        redist = self.root / 'redist'
        crt = redist / 'x64/Microsoft.VC143.CRT'
        crt.mkdir(parents=True)
        (crt / 'vcruntime140.dll').write_bytes(b'incomplete')
        output = self.root / 'tools'
        output.mkdir()
        with patch.dict(os.environ, {'VCToolsRedistDir': str(redist)}):
            with self.assertRaisesRegex(RuntimeError, 'incomplete'):
                copy_visual_cpp_runtime(output)


if __name__ == '__main__':
    unittest.main()
