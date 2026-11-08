# NeuralNote Fedora COPR — Git-hosted source package

**Packaging prototype** for NeuralNote **2.2.0** on **Fedora x86_64**.
Installs both the standalone GUI and the VST3 plugin. No Flatpaks, no binary
artifacts in Git, and no manual SRPM uploading. This is an SCM **make_srpm**
workflow, not the plain `rpkg` source method.

> **Build / publication status:** static checks and local source RPM generation
> pass for 2.2.0. CMake selected Fedora's default Clang 23.1.4 in a local
> build, which was stopped after more than 11 minutes compiling ggml's Vulkan
> backend. Binary builds, standalone/VST3 runtime behavior and COPR jobs remain
> unverified. Review third-party licenses (especially JUCE) before publicly
> distributing packages. MuScriptor CC BY-NC model weights are never included.

## Flow

```text
GitHub repository (neuralnote.spec, .copr/Makefile, scripts/)
             |
             | COPR SCM checkout of selected Git revision
             v
COPR source builder: make srpm
  - installs source-builder tools
  - fetches NeuralNote v2.2.0 and its pinned Git submodules
  - fetches the muscriptor.cpp-pinned ggml revision
  - invokes the upstream checksum-verified SoundFont builder
  - packs all of that into Source0
  - runs rpmbuild -bs -> source RPM
             |
             v
COPR Fedora RPM builder (without fetching any sources)
  - Fedora default Clang / CMake / JUCE / muscriptor.cpp / ggml
  - installs neuralnote, .desktop and NeuralNote.vst3
             |
             v
COPR repository -> dnf5 install neuralnote
```

## Publish to GitHub

1. Create an **empty repository** named `neuralnote-copr` in your GitHub account.
2. Unzip this kit, enter `neuralnote-copr-scm`, and run:

   ```bash
   python3 scripts/verify-kit.py
   bash -n scripts/*.sh
   git init -b main
   git add .
   git commit -m "Package NeuralNote 2.2.0 for Fedora via COPR SCM"
   git remote add origin https://github.com/YOUR_GITHUB_USERNAME/neuralnote-copr.git
   git push -u origin main
   ```

**Do not commit** local `~/.config/copr`, GitHub access tokens, downloaded model
weights, bundled binary tarballs, or generated SRPM/RPM files.

## Configure COPR

For a **new** COPR project, with `copr-cli` configured using credentials from
<https://copr.fedorainfracloud.org/api/>, replace `YOUR_FEDORA_CHROOT` below
with your chosen Fedora x86_64 chroot:

```bash
sudo dnf5 install copr-cli
copr-cli create --chroot YOUR_FEDORA_CHROOT neuralnote
copr-cli add-package-scm neuralnote \
  --name neuralnote \
  --clone-url https://github.com/YOUR_GITHUB_USERNAME/neuralnote-copr.git \
  --commit main --type git --method make_srpm \
  --spec neuralnote.spec --webhook-rebuild off
copr-cli build-package neuralnote --name neuralnote
```

If the **project already exists**, skip `create`. If its `neuralnote` package
already exists, use `copr-cli edit-package-scm` (same options) or edit the
source settings in the COPR web interface. Do **not** add a duplicate package.

COPR SCM source settings: **Git**, Clone URL = your packaging repo, Committish
=`main`, Subdirectory = empty/root, Spec = `neuralnote.spec`, method =
**make srpm**. With this method, COPR invokes the checked-in `.copr/Makefile`
`srpm` target. See official COPR documentation:
<https://docs.copr.fedorainfracloud.org/user_documentation.html>.

Once a real build passes and licensing is cleared, you can turn on automatic
rebuilds on GitHub pushes. Details in [COPR-WEBHOOK.md](COPR-WEBHOOK.md).

## Install a successful build

```bash
sudo dnf5 copr enable YOUR_FEDORA_ACCOUNT/neuralnote
sudo dnf5 install neuralnote
neuralnote
```

Expected outputs: `/usr/bin/neuralnote`, a GNOME `.desktop` launcher, and
`/usr/lib64/vst3/NeuralNote.vst3/` on x86_64.

## Development and troubleshooting

- Run `python3 scripts/verify-kit.py` after every packaging edit.
- Offline static validation does **not** validate Fedora package availability,
  C++ compilation, VST3 runtime loading, or the licensing of the full bundle.
- For local source-stage reproduction (downloads upstream sources):
  `bash scripts/build-srpm.sh ./dist` — optional, **not needed for COPR**.
- For source-builder failures, inspect the COPR **SRPM generation** logs. For
  RPM build failures, inspect `builder-live.log`, `build.log`, and CMake output.
- If Vulkan build fails, temporarily switch `%bcond_without vulkan` to
  `%bcond_with vulkan` in `neuralnote.spec` and re-run the build. CPU-only is a
  diagnostic fallback, not a claim that GPU is unnecessary.
- Source0 is a bundled source archive because upstream CMake needs JUCE,
  muscriptor.cpp, ggml and a generated SF3. The binary RPM stage is offline.
- The source assembly uses upstream release tag v2.2.0; tag and submodule
  identities are recorded in `SOURCE-PROVENANCE.txt`. To obtain a fully
  *immutable* publication process, also pin/verify the release commit SHA
  in the source stage during release qualification.
- ggml's pinned revision is read from the release's muscriptor.cpp CMake,
  rather than a moving branch. Do not silently change the pin.

## Contents

- `neuralnote.spec` — RPM spec (standalone + VST3; Vulkan enabled by default)
- `.copr/Makefile` — COPR `make_srpm` entrypoint
- `scripts/prepare-sources.sh` — gather verified upstream sources and assets
- `scripts/build-srpm.sh` — source RPM constructor
- `scripts/verify-kit.py` — offline validation
- `.github/workflows/check.yml` — small offline GitHub Actions lint check
- `COPR-WEBHOOK.md` — optional push-trigger automation

## Licensing before public distribution

NeuralNote source code is Apache-2.0, but vendored JUCE has its own AGPL or
commercial licensing conditions. The exact bundled version and runtime linking
must be reviewed for lawful redistribution. The build includes a generated
SoundFont whose original credits must be retained. MuScriptor GGUF weights are
CC BY-NC 4.0 and deliberately excluded; users may download them separately
through the app and must respect that license. The spec's composite License
field is **provisional pending review**; a successful RPM build does not grant
any otherwise unavailable redistribution rights.
