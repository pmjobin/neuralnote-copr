#!/usr/bin/env bash
# Produce a fully self-contained Source0 archive OUTSIDE the RPM build chroot.
# Network access is required here, but MUST NOT be needed in %prep/%build.
set -Eeuo pipefail

VERSION=2.1.0
NAME="neuralnote-${VERSION}-vendored.tar.xz"
OUTDIR="${1:-$PWD/dist}"
mkdir -p -- "$OUTDIR"
OUTDIR="$(cd "$OUTDIR" && pwd -P)"
TMPDIR_BUILD="$(mktemp -d)"
trap 'rm -rf -- "$TMPDIR_BUILD"' EXIT

ROOT="$TMPDIR_BUILD/NeuralNote-${VERSION}"
STAGE="$TMPDIR_BUILD/stage/NeuralNote-${VERSION}"

echo "==> Cloning immutable NeuralNote release tag v${VERSION}"
git clone -q --branch "v${VERSION}" --depth 1 https://github.com/DamRsn/NeuralNote.git "$ROOT"
git -C "$ROOT" submodule sync --recursive
git -C "$ROOT" submodule update --init --recursive --depth 1

test -f "$ROOT/ThirdParty/muscriptor.cpp/cpp/CMakeLists.txt"
test -f "$ROOT/ThirdParty/JUCE/modules/juce_core/juce_core.h"

echo "==> Capturing exact source commit and checked-out submodules"
NEURALNOTE_HEAD="$(git -C "$ROOT" rev-parse HEAD)"
git -C "$ROOT" submodule status --recursive > "$TMPDIR_BUILD/submodules.txt"
cat "$TMPDIR_BUILD/submodules.txt"

# Read muscriptor.cpp's actual pinned ggml commit from the exact release submodule.
# This is intentionally not hard-coded to whatever muscriptor's moving main
# branch happens to use when the packaging kit is authored.
GGML_COMMIT="$(python3 - "$ROOT/ThirdParty/muscriptor.cpp/cpp/CMakeLists.txt" <<'PYGGML'
import pathlib, re, sys
s=pathlib.Path(sys.argv[1]).read_text()
m=re.search(r'^\s*set\(\s*MUSCRIPTOR_GGML_COMMIT\s+([0-9a-fA-F]{40})\b',s,re.M)
if not m: raise SystemExit('Could not locate a 40-hex ggml commit in pinned muscriptor.cpp')
print(m.group(1).lower())
PYGGML
)"
echo "==> Fetching ggml fork commit pinned by muscriptor.cpp: ${GGML_COMMIT}"
GGML="$TMPDIR_BUILD/ggml"
mkdir -p "$GGML"
git -C "$GGML" init -q
git -C "$GGML" remote add origin https://github.com/DamRsn/ggml.git
git -C "$GGML" fetch -q --depth 1 origin "$GGML_COMMIT"
git -C "$GGML" checkout -q --detach FETCH_HEAD
[[ "$(git -C "$GGML" rev-parse HEAD)" == "$GGML_COMMIT" ]]

echo "==> Building the upstream SHA-256-verified embedded soundfont"
# Upstream verifies both inputs and the resulting sf3 digest.
python3 "$ROOT/Tools/fetch_soundfont.py"
SOUNDFONT_SHA="$(python3 - "$ROOT/Tools/make_soundfont.py" <<'PYSF'
import pathlib, re, sys
s=pathlib.Path(sys.argv[1]).read_text()
m=re.search(r'^\s*OUTPUT_SHA256\s*=\s*[\"\']([0-9a-fA-F]{64})[\"\']',s,re.M)
if not m: raise SystemExit('No pinned SoundFont output digest found')
print(m.group(1).lower())
PYSF
)"
ACTUAL_SOUNDFONT_SHA="$(sha256sum "$ROOT/NeuralNote/Assets/SoundFont/NeuralNote_GM.sf3" | cut -d' ' -f1)"
[[ "$ACTUAL_SOUNDFONT_SHA" == "$SOUNDFONT_SHA" ]] || {
    echo "ERROR: derived SoundFont checksum mismatch" >&2
    exit 1
}
echo "SoundFont verified: $SOUNDFONT_SHA"

echo "==> Making source tree without Git metadata or downloaded build caches"
mkdir -p "$STAGE"
# Use tar to preserve symlinks, executable bits and nested submodule content.
tar -C "$ROOT" --exclude-vcs --exclude='build' --exclude='__pycache__' \
    --exclude='MuseScore_General.sf3' --exclude='FluidR3Mono_GM.sf3' \
    -cf - . | tar -C "$STAGE" -xf -
mkdir -p "$STAGE/ThirdParty/ggml-pinned" "$STAGE/packaging"
tar -C "$GGML" --exclude-vcs -cf - . | tar -C "$STAGE/ThirdParty/ggml-pinned" -xf -
cp "$(dirname "$0")/../neuralnote.desktop" "$STAGE/packaging/neuralnote.desktop"
cat > "$STAGE/packaging/SOURCE-PROVENANCE.txt" <<EOF
NeuralNote: v${VERSION} (${NEURALNOTE_HEAD})
Upstream: https://github.com/DamRsn/NeuralNote
Submodules (git submodule status --recursive):
$(cat "$TMPDIR_BUILD/submodules.txt")
GGML fork: https://github.com/DamRsn/ggml @ ${GGML_COMMIT}
Embedded SF3: sha256=${SOUNDFONT_SHA}
The two larger input SF3 files are omitted to avoid duplicating storage.
Their source URLs and SHA256 digests are pinned in Tools/fetch_soundfont.py;
source license notices are retained in NeuralNote/Assets/SoundFont/.
MuScriptor model weights: NOT present in source, SRPM, or RPM.
EOF

test -f "$STAGE/ThirdParty/ggml-pinned/CMakeLists.txt"
test -f "$STAGE/NeuralNote/Assets/SoundFont/NeuralNote_GM.sf3"
if find "$STAGE" -name .git -print -quit | grep -q .; then
    echo "ERROR: leaked Git metadata" >&2
    exit 1
fi

tar -C "$TMPDIR_BUILD/stage" -cJf "$OUTDIR/$NAME" "NeuralNote-${VERSION}"
sha256sum "$OUTDIR/$NAME" | tee "$OUTDIR/${NAME}.sha256"
echo "Source0 ready: $OUTDIR/$NAME"
