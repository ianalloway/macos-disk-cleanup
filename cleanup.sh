#!/usr/bin/env bash
#
# =============================================================================
# ALGORITHM: selective macOS disk reclamation (cache / regenerable data only)
# =============================================================================
#
# Goal
#   Reclaim space by deleting items the OS or apps can recreate, without
#   touching irreplaceable user content (documents, passwords, stable profile
#   state).
#
# Invariants (must hold for every deletion)
#   I1. Target is classified REGENERABLE: rebuilt, re-downloaded, or refetched
#       by the owning component on next use.
#   I2. Target is not user-authored primary data (e.g. ~/Documents, git repos,
#       photos) unless it is explicitly a named cache subtree.
#   I3. Browser profile: never delete Extensions/ (unpacked), Bookmarks,
#       Login Data, Preferences, Cookies as a blanket operation; only named
#       cache / model-store / service-worker subtrees in phase_chromium_caches().
#   I4. Go module trees are read-only on disk; reclamation requires chmod -R u+w
#       on the module root before rm, or GOMODCACHE must point at that root
#       before go clean -modcache. Tools that inject a fake GOMODCACHE (IDEs)
#       must be bypassed by clearing env or using explicit paths.
#
# Phases (order: cheap tooling first, then large app blobs; order does not
# change correctness, only makes logs easier to read)
#
#   P1  BASELINE     — sample free space on APFS Data volume (df).
#   P2  PACKAGES      — Homebrew cleanup; npm cache; pip cache (if present).
#   P3  GO_BUILD      — go clean -cache with GOMODCACHE/GOCACHE unset so the
#                       user’s real build cache is targeted.
#   P4  GO_MODULES    — delete $GOPATH/pkg/mod (and sumdb) after chmod u+w;
#                       optional in profile “minimal” (skip P4).
#   P5  APP_VM        — delete known large VM bundle dirs (regenerable).
#   P6  OS_WALLPAPER  — delete downloaded aerial wallpaper payloads.
#   P7  UPDATER_CRX   — browser updater CRX cache + version staging dirs.
#   P8  CHROMIUM      — delete only paths listed in phase_chromium_caches().
#   P9  DOCKER        — docker system prune (only profile “full”).
#   P10 XCODE         — DerivedData (only profile “full”).
#   P11 REPORT       — print approximate free-space change.
#
# Profiles
#   minimal — P1,P2,P3,P11 (no browsers, no app VMs, no Go modules)
#   default — P1–P8,P11
#   full    — P1–P11
#
# Extending the algorithm
#   Add a new row only after classifying the path as REGENERABLE per I1–I3.
#   Prefer vendor commands (brew, go clean, docker prune) over raw rm when
#   they exist.
#
# =============================================================================

set -uo pipefail

readonly PROGNAME=$(basename "$0")

DRY_RUN=0
PROFILE=default

usage() {
	cat <<EOF
${PROGNAME} — macOS cache reclamation (see algorithm header in script).

Usage: $PROGNAME [--dry-run] [--minimal|--full] [--help]

  --dry-run   Log actions only.
  --minimal   Package managers + Go build cache only.
  --default   (implicit) Full safe set through Chromium caches.
  --full      Also Docker prune + Xcode DerivedData when tools/paths exist.
  -h, --help  This help.
EOF
}

log() { printf '%s\n' "$*"; }
info() { printf '\033[0;36m→\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m!\033[0m %s\n' "$*" >&2; }

data_volume_free_kb() {
	df -k /System/Volumes/Data 2>/dev/null | awk 'NR==2 {print $4}'
}

run_rm_rf() {
	local path=$1
	[[ -e $path ]] || return 0
	if ((DRY_RUN)); then
		info "[dry-run] rm -rf ${path/#$HOME/~}"
		return 0
	fi
	rm -rf "$path"
}

run_cmd() {
	if ((DRY_RUN)); then
		info "[dry-run] $*"
		return 0
	fi
	"$@"
}

# --- P2 PACKAGES -------------------------------------------------------------

phase_packages() {
	command -v brew >/dev/null 2>&1 && {
		info "[P2] Homebrew cleanup"
		run_cmd brew cleanup -s --prune=all
	}
	command -v npm >/dev/null 2>&1 && {
		info "[P2] npm cache"
		run_cmd npm cache clean --force
	}
	command -v pip3 >/dev/null 2>&1 && {
		info "[P2] pip cache"
		if ((DRY_RUN)); then
			info "[dry-run] pip3 cache purge"
		else
			pip3 cache purge 2>/dev/null || true
		fi
	}
}

# --- P3–P4 GO ----------------------------------------------------------------

phase_go_build() {
	command -v go >/dev/null 2>&1 || return 0
	info "[P3] Go build cache (strip IDE GOMODCACHE/GOCACHE)"
	if ((DRY_RUN)); then
		info "[dry-run] env -u GOMODCACHE -u GOCACHE go clean -cache"
		return 0
	fi
	env -u GOMODCACHE -u GOCACHE go clean -cache 2>/dev/null || go clean -cache 2>/dev/null || true
}

phase_go_modules() {
	command -v go >/dev/null 2>&1 || return 0
	local gopath mod sumdb
	gopath="${GOPATH:-$HOME/go}"
	mod="$gopath/pkg/mod"
	sumdb="$gopath/pkg/sumdb"
	[[ -d $mod ]] || return 0
	info "[P4] Go module cache: $mod"
	if ((DRY_RUN)); then
		info "[dry-run] chmod -R u+w; rm -rf $mod/* $sumdb/*"
		return 0
	fi
	chmod -R u+w "$mod" 2>/dev/null || true
	rm -rf "${mod:?}/"*
	if [[ -d $sumdb ]]; then
		chmod -R u+w "$sumdb" 2>/dev/null || true
		rm -rf "${sumdb:?}/"*
	fi
}

# --- P5 Large app VM bundles (REGENERABLE class; extend cautiously) -----------

phase_app_vm_bundles() {
	# Tuple: relative path under \$HOME/Library/Application Support
	local -a rel=(
		"Claude/vm_bundles"
	)
	local base="$HOME/Library/Application Support"
	local r p
	for r in "${rel[@]}"; do
		p="$base/$r"
		[[ -d $p ]] || continue
		info "[P5] App VM bundles: $r"
		run_rm_rf "$p"
	done
	# Small Chromium-style caches co-located with same apps (optional, same invariant)
	local claude="$HOME/Library/Application Support/Claude"
	[[ -d $claude ]] || return 0
	for d in GPUCache DawnWebGPUCache DawnGraphiteCache "Code Cache"; do
		run_rm_rf "$claude/$d"
	done
}

# --- P6 OS wallpaper payloads -------------------------------------------------

phase_wallpaper_aerials() {
	local a="$HOME/Library/Application Support/com.apple.wallpaper/aerials"
	[[ -d $a ]] || return 0
	info "[P6] macOS aerial wallpaper downloads"
	run_rm_rf "$a"
}

# --- P7 Updater CRX cache -----------------------------------------------------

phase_google_updater() {
	local gu="$HOME/Library/Application Support/Google/GoogleUpdater"
	[[ -d $gu ]] || return 0
	info "[P7] Google Updater cache"
	run_rm_rf "$gu/crx_cache"
	if ((DRY_RUN)); then
		info "[dry-run] remove *.old logs + numeric version dirs in GoogleUpdater"
	else
		rm -f "$gu/updater.log.old" "$gu/updater_history.jsonl.old" 2>/dev/null || true
		find "$gu" -maxdepth 1 -type d -regex '.*/[0-9][0-9.]*$' 2>/dev/null | while read -r d; do
			rm -rf "$d"
		done
	fi
}

# --- P8 Chromium-class profile caches (see invariant I3) ----------------------

phase_chromium_caches() {
	local ch="$HOME/Library/Application Support/Google/Chrome"
	[[ -d $ch ]] || return 0
	# Paths relative to Chrome root — all REGENERABLE per I3
	local -a rel=(
		"Default/Service Worker"
		"Default/GPUCache"
		"Default/DawnWebGPUCache"
		"Default/DawnGraphiteCache"
		"GrShaderCache"
		"GraphiteDawnCache"
		"ShaderCache"
		"optimization_guide_model_store"
		"extensions_crx_cache"
		"component_crx_cache"
		"WasmTtsEngine"
		"Default/Shared Dictionary"
	)
	local r p
	info "[P8] Chrome regenerable caches"
	for r in "${rel[@]}"; do
		p="$ch/$r"
		run_rm_rf "$p"
	done
}

# --- P9 Docker (full only) ----------------------------------------------------

phase_docker() {
	command -v docker >/dev/null 2>&1 || return 0
	info "[P9] Docker system prune"
	if ((DRY_RUN)); then
		info "[dry-run] docker system prune -af --volumes"
		return 0
	fi
	docker system prune -af --volumes 2>/dev/null || warn "Docker prune failed (is the daemon running?)"
}

# --- P10 Xcode DerivedData (full only) ----------------------------------------

phase_xcode_derived() {
	local dd="$HOME/Library/Developer/Xcode/DerivedData"
	[[ -d $dd ]] || return 0
	info "[P10] Xcode DerivedData"
	run_rm_rf "$dd"
}

# --- P1 / P11 -----------------------------------------------------------------

main() {
	while [[ $# -gt 0 ]]; do
		case $1 in
		--dry-run) DRY_RUN=1 ;;
		--minimal) PROFILE=minimal ;;
		--default) PROFILE=default ;;
		--full) PROFILE=full ;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			printf 'Unknown option: %s\n' "$1" >&2
			usage >&2
			exit 1
			;;
		esac
		shift
	done

	local before after
	before=$(data_volume_free_kb) || true

	log ""
	log "=== ${PROGNAME} — profile=${PROFILE} ==="
	((DRY_RUN)) && warn "Dry run: no filesystem changes."

	# P1 baseline (informational)
	info "[P1] Data volume free (df 1K-blocks): ${before:-?}"

	if [[ $PROFILE == minimal ]]; then
		phase_packages
		phase_go_build
	else
		phase_packages
		phase_go_build
		phase_go_modules
		phase_app_vm_bundles
		phase_wallpaper_aerials
		phase_google_updater
		phase_chromium_caches
		[[ $PROFILE == full ]] && phase_docker
		[[ $PROFILE == full ]] && phase_xcode_derived
	fi

	after=$(data_volume_free_kb) || true
	if [[ -n ${before:-} && -n ${after:-} ]]; then
		log ""
		info "[P11] Free ~$((after / 1024 / 1024)) GiB (was ~$((before / 1024 / 1024)) GiB; df 1K-blocks on Data)"
	fi
	log ""
	info "Finished."
}

main "$@"
