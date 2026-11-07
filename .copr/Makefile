# COPR package source: SCM (Git) -> "make srpm".
# COPR passes outdir and spec as make variables. The SRPM is the ONLY output
# the source builder needs; the binary chroot builds offline from Source0.
.PHONY: srpm
srpm:
	@set -eu; \
	if command -v dnf5 >/dev/null 2>&1; then pkg=dnf5; else pkg=dnf; fi; \
	$$pkg -y install git python3 rpm-build tar xz coreutils findutils ca-certificates; \
	bash ./scripts/build-srpm.sh "$(outdir)"
