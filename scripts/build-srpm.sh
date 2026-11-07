#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
OUTDIR="${1:-$PROJECT_ROOT/dist}"
mkdir -p "$OUTDIR"
OUTDIR="$(cd "$OUTDIR" && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$TMP/SOURCES" "$TMP/SPECS" "$TMP/SRPMS" "$TMP/BUILD" "$TMP/BUILDROOT" "$TMP/RPMS"

"$PROJECT_ROOT/scripts/prepare-sources.sh" "$TMP/SOURCES"
cp "$PROJECT_ROOT/neuralnote.spec" "$TMP/SPECS/neuralnote.spec"
rpmbuild -bs --define "_topdir $TMP" "$TMP/SPECS/neuralnote.spec"
SRPM=("$TMP"/SRPMS/neuralnote-*.src.rpm)
if [[ ! -f "${SRPM[0]}" ]]; then echo "No SRPM generated" >&2; exit 1; fi
cp "${SRPM[0]}" "$OUTDIR/"
sha256sum "$OUTDIR/$(basename "${SRPM[0]}")"
echo "SRPM ready: $OUTDIR/$(basename "${SRPM[0]}")"
