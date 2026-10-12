import os
import shutil
import subprocess
from pathlib import Path


def copy_visual_cpp_runtime(destination):
    configured = os.environ.get('VCToolsRedistDir')
    if configured:
        redist = Path(configured)
    else:
        vswhere = Path(os.environ.get('ProgramFiles(x86)', r'C:\Program Files (x86)')) / 'Microsoft Visual Studio/Installer/vswhere.exe'
        installation = subprocess.check_output([
            str(vswhere), '-latest', '-products', '*', '-requires',
            'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
            '-property', 'installationPath',
        ], text=True).strip()
        if not installation:
            raise RuntimeError('Install Visual Studio Desktop development with C++')
        candidates = [p for p in (Path(installation) / 'VC/Redist/MSVC').iterdir()
                      if p.is_dir() and all(part.isdigit() for part in p.name.split('.'))]
        if not candidates:
            raise RuntimeError('Visual C++ redistributable files are missing')
        redist = max(candidates, key=lambda p: tuple(int(n) for n in p.name.split('.')))
    directories = list((redist / 'x64').glob('Microsoft.VC*.CRT'))
    if len(directories) != 1:
        raise RuntimeError('Cannot locate the x64 Visual C++ CRT in ' + str(redist))
    copied = []
    for dll in sorted(directories[0].glob('*.dll')):
        shutil.copy2(dll, destination / dll.name)
        copied.append(dll.name.lower())
    if not {'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll'}.issubset(copied):
        raise RuntimeError('Visual C++ runtime is incomplete')
