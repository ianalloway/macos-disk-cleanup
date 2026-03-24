# macos-disk-cleanup

[![CI](https://github.com/ianalloway/macos-disk-cleanup/actions/workflows/ci.yml/badge.svg)](https://github.com/ianalloway/macos-disk-cleanup/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=white)](https://github.com/ianalloway/macos-disk-cleanup)
[![Bash](https://img.shields.io/badge/bash-script-4EAA25?logo=gnubash&logoColor=white)](bin/macos-disk-cleanup)

**Free up disk space on macOS** by clearing *regenerable* caches only: Homebrew, npm, pip, Go, Google Chrome caches, macOS wallpaper payloads, optional Docker / Xcode junk—and **not** your passwords, bookmarks, or extension code.

Search hits: *disk space*, *storage full*, *clear cache mac*, *free space macOS*, *Homebrew cleanup*, *Chrome cache mac*, *Go modcache*, *DerivedData*, *Docker prune*, *Claude vm_bundles*.

---

## Contents

- [Why this repo](#why-this-repo)
- [Quick start](#quick-start)
- [What it cleans (by profile)](#what-it-cleans-by-profile)
- [The algorithm](#the-algorithm)
- [Optional: GitHub CLI login helper](#optional-github-cli-login-helper)
- [Repository layout](#repository-layout)
- [Suggested GitHub topics](#suggested-github-topics)
- [Disclaimer](#disclaimer)

---

## Why this repo

macOS “System Data” and developer tooling can grow for years. This project is a **documented, reviewable Bash tool** that:

- prefers **vendor commands** (`brew`, `go clean`, `docker`) where possible;
- applies **explicit invariants** (only delete what can be rebuilt);
- supports **`--dry-run`** so you can see intent before deleting anything.

---

## Quick start

```bash
git clone https://github.com/ianalloway/macos-disk-cleanup.git
cd macos-disk-cleanup
chmod +x bin/macos-disk-cleanup bin/gh-auth

# Always preview first
./bin/macos-disk-cleanup --dry-run

# Then run (default profile)
./bin/macos-disk-cleanup
```

Install on your `PATH` (optional):

```bash
ln -sf "$(pwd)/bin/macos-disk-cleanup" /usr/local/bin/macos-disk-cleanup
# or: mkdir -p ~/bin && ln -sf "$(pwd)/bin/macos-disk-cleanup" ~/bin/
```

---

## What it cleans (by profile)

| Area | `minimal` | default | `--full` |
|------|:---------:|:-------:|:--------:|
| Homebrew `cleanup` | ✓ | ✓ | ✓ |
| npm / pip caches | ✓ | ✓ | ✓ |
| Go **build** cache (`go clean -cache`) | ✓ | ✓ | ✓ |
| Go **module** cache (`$GOPATH/pkg/mod`) | — | ✓ | ✓ |
| Large **app VM bundles** (e.g. Claude `vm_bundles`) + small GPU caches | — | ✓ | ✓ |
| **macOS aerial** wallpaper downloads | — | ✓ | ✓ |
| **Google Updater** CRX cache | — | ✓ | ✓ |
| **Chrome** regenerable caches (not bookmarks/passwords) | — | ✓ | ✓ |
| **Docker** `system prune` | — | — | ✓ |
| **Xcode** `DerivedData` | — | — | ✓ |

Flags: `--dry-run`, `--minimal`, `--full`, `-h`.

---

## The algorithm

The **full specification** (invariants **I1–I4**, phases **P1–P11**, profiles) lives in the header of [`bin/macos-disk-cleanup`](bin/macos-disk-cleanup). Read that block before extending paths or adding new delete rules.

---

## Optional: GitHub CLI login helper

[`bin/gh-auth`](bin/gh-auth) wraps `gh auth` for **local** browser login (credentials stay in Keychain / `gh` config).

```bash
./bin/gh-auth login
./bin/gh-auth setup-git   # optional: gh as git credential helper
./bin/gh-auth status
```

Requires: `brew install gh` — [GitHub CLI](https://cli.github.com).

---

## Repository layout

```
macos-disk-cleanup/
├── bin/
│   ├── macos-disk-cleanup   # main cleanup CLI + documented algorithm
│   └── gh-auth              # optional GitHub CLI auth helper
├── .github/
│   └── workflows/
│       └── ci.yml           # ShellCheck on push/PR
├── LICENSE                  # MIT
└── README.md
```

---

## Suggested GitHub topics

Add these in **Repository → ⚙ Settings → General → Topics** to improve discovery:

`macos` · `bash` · `shell` · `disk-space` · `storage` · `cache` · `homebrew` · `google-chrome` · `golang` · `docker` · `xcode` · `cleanup` · `cli` · `automation`

---

## Disclaimer

Software is provided **as-is** under the [MIT License](LICENSE). You are responsible for backups and for understanding what gets deleted. **Preview with `--dry-run`.** This is not affiliated with Apple, Google, Anthropic, or GitHub.
