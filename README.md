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

## License

Use at your own risk; you are responsible for backups and for understanding what the script deletes.
