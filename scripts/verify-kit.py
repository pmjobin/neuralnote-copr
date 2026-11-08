#!/usr/bin/env python3
"""Offline static packaging-kit checks; does not claim a Fedora build."""
import hashlib
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parent.parent
required = [
    'neuralnote.spec', 'neuralnote.desktop', 'README.md',
    '.copr/Makefile', 'scripts/prepare-sources.sh', 'scripts/build-srpm.sh',
]
for f in required:
    path = root / f
    assert path.is_file() and path.stat().st_size > 0, f
for file in ['scripts/prepare-sources.sh', 'scripts/build-srpm.sh']:
    subprocess.run(['bash', '-n', str(root / file)], check=True)
spec = (root/'neuralnote.spec').read_text()
prep = (root/'scripts/prepare-sources.sh').read_text()
make = (root/'.copr/Makefile').read_text()
assert 'Version:        2.2.0' in spec
assert 'VERSION=2.2.0' in prep
assert 'Source0:        neuralnote-%{version}-vendored.tar.xz' in spec
assert '%bcond_without vulkan' in spec
assert '-DFETCHCONTENT_FULLY_DISCONNECTED=ON' in spec
assert '-DNEURALNOTE_FETCH_SOUNDFONT=OFF' in spec
assert 'NeuralNote_Standalone NeuralNote_VST3' in spec
assert 'v${VERSION}' in prep
assert 'MUSCRIPTOR_GGML_COMMIT' in prep and 'GGML_COMMIT=' in prep
assert 'OUTPUT_SHA256' in prep and 'ACTUAL_SOUNDFONT_SHA' in prep
assert 'submodule update --init --recursive --depth 1' in prep
assert 'srpm:' in make and 'scripts/build-srpm.sh' in make
assert 'MuScriptor model weights: NOT present' in prep
print('PASS: 6 required files, shell syntax, CMake offline guards, pinned source data, COPR SCM hook, desktop launcher')
for f in required:
    data = (root/f).read_bytes()
    print(f'{hashlib.sha256(data).hexdigest()}  {f}')
