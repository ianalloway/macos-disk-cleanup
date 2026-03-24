# macos-disk-cleanup

Selective macOS disk reclamation: removes **regenerable** caches (package managers, Go, Chromium-class browser caches, some app VM bundles, etc.) without touching passwords, bookmarks, or extension code.

The **algorithm** (invariants, phases, profiles) is documented at the top of [`cleanup.sh`](cleanup.sh).

## Requirements

- macOS
- Bash (preinstalled)

## Usage

```bash
chmod +x cleanup.sh
./cleanup.sh              # default: safe cache set
./cleanup.sh --dry-run
./cleanup.sh --minimal    # brew, npm, pip, Go build cache only
./cleanup.sh --full       # default + Docker prune + Xcode DerivedData
```

Review `--dry-run` output before running without it on a machine you care about.

## GitHub CLI auth (local)

[`gh-auth`](gh-auth) wraps `gh auth` so you can log in on this Mac with the browser flow (credentials stay in Keychain / `gh`’s config—nothing runs “in the cloud” except talking to GitHub).

```bash
chmod +x gh-auth
./gh-auth login        # browser login to github.com (HTTPS)
./gh-auth setup-git    # optional: use gh as git credential helper
./gh-auth status
```

Other commands: `./gh-auth check` (silent, for scripts), `./gh-auth login-ssh`, `./gh-auth refresh`, `./gh-auth logout`. Requires [GitHub CLI](https://cli.github.com): `brew install gh`.

## License

Use at your own risk; you are responsible for backups and for understanding what the script deletes.
