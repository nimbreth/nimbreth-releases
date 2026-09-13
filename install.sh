#!/usr/bin/env bash
set -euo pipefail

GITHUB_REPO="nimbreth/nimbreth-releases"
INSTALL_DIR="${NIMBRETH_INSTALL_DIR:-$HOME/.local/share/nimbreth}"
BIN_DIR="${NIMBRETH_BIN_DIR:-$HOME/.local/bin}"

usage() {
    cat <<EOF
Nimbreth installer — downloads and installs the standalone CLI/TUI.

Usage:
  curl -fsSL https://raw.githubusercontent.com/$GITHUB_REPO/main/install.sh | bash
  curl -fsSL ... | bash -s -- --version 0.1.0

Options:
  --version <ver>   Install a specific version (default: latest release)
  --install-dir     Installation directory (default: $INSTALL_DIR)
  --bin-dir         Directory for symlinks, should be in PATH (default: $BIN_DIR)
  --uninstall       Remove nimbreth and its symlinks
  --help            Show this message

Environment:
  NIMBRETH_INSTALL_DIR  Alternative way to set installation directory
  NIMBRETH_BIN_DIR      Alternative way to set bin directory

Installed versions live under versions/<ver>/ with an atomic current
symlink, enabling \`nimbreth update --rollback\`.
EOF
    exit 0
}

VERSION=""
UNINSTALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)     VERSION="$2"; shift 2 ;;
        --install-dir) INSTALL_DIR="$2"; shift 2 ;;
        --bin-dir)     BIN_DIR="$2"; shift 2 ;;
        --uninstall)   UNINSTALL=true; shift ;;
        --help)        usage ;;
        *)             echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

detect_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Linux)  os="linux" ;;
        Darwin) os="darwin" ;;
        *)      echo "Error: unsupported OS: $os" >&2; exit 1 ;;
    esac

    case "$arch" in
        x86_64|amd64)  arch="x64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)             echo "Error: unsupported architecture: $arch" >&2; exit 1 ;;
    esac

    if [[ "$os" == "darwin" && "$arch" == "x64" ]]; then
        echo "Error: Nimbreth for macOS is Apple Silicon (arm64) only; Intel Macs are not supported." >&2
        echo "If you need an Intel build, tell us at hello@nimbreth.com" >&2
        exit 1
    fi

    PLATFORM="$os"
    ARCH="$arch"
}

resolve_version() {
    if [[ -n "$VERSION" ]]; then
        return
    fi

    echo "==> Fetching latest release version..."
    local api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"

    if command -v curl &>/dev/null; then
        VERSION=$(curl -fsSL "$api_url" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')
    elif command -v wget &>/dev/null; then
        VERSION=$(wget -qO- "$api_url" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')
    else
        echo "Error: curl or wget is required." >&2
        exit 1
    fi

    if [[ -z "$VERSION" ]]; then
        echo "Error: could not determine latest version from GitHub." >&2
        echo "Specify a version manually: --version <ver>" >&2
        exit 1
    fi
}

download() {
    local url="$1" dest="$2"
    if command -v curl &>/dev/null; then
        curl -fSL --progress-bar -o "$dest" "$url"
    elif command -v wget &>/dev/null; then
        wget --show-progress -qO "$dest" "$url"
    fi
}

verify_checksum() {
    local tarball="$1" expected_file="$2"

    if [[ ! -f "$expected_file" ]]; then
        echo "    Warning: checksum file not available, skipping verification."
        return
    fi

    local expected actual
    expected="$(awk '{print $1}' "$expected_file")"
    if command -v sha256sum &>/dev/null; then
        actual="$(sha256sum "$tarball" | awk '{print $1}')"
    elif command -v shasum &>/dev/null; then
        actual="$(shasum -a 256 "$tarball" | awk '{print $1}')"
    else
        echo "    Warning: no checksum tool available, skipping verification."
        return
    fi

    if [[ "$expected" != "$actual" ]]; then
        echo "Error: SHA256 checksum mismatch!" >&2
        echo "  Expected: $expected" >&2
        echo "  Got:      $actual" >&2
        rm -f "$tarball" "$expected_file"
        exit 1
    fi

    echo "    SHA256 checksum verified."
}

# Channel inference: a semver with a prerelease suffix (e.g. "0.1.0-beta.1")
# pins the install to the beta channel; bare versions are stable.
infer_channel() {
    local ver="$1"
    case "$ver" in
        *-*) echo "beta" ;;
        *)   echo "stable" ;;
    esac
}

# Atomic symlink swap: ln -sfn followed by rename keeps current valid at all
# times. Falls back to remove+create on filesystems that don't support atomic
# rename of symlinks (rare; documented limitation).
swap_current_symlink() {
    local target="$1"
    local current_link="$INSTALL_DIR/current"
    local tmp_link="$INSTALL_DIR/.current.tmp"

    rm -f "$tmp_link"
    ln -s "$target" "$tmp_link"
    if mv -f "$tmp_link" "$current_link" 2>/dev/null; then
        return 0
    fi

    # Fallback: filesystem doesn't support atomic rename for symlinks.
    rm -f "$current_link"
    ln -s "$target" "$current_link"
}

create_symlinks() {
    mkdir -p "$BIN_DIR"

    local bins=("nimbreth" "nimbreth-cli" "nimbreth-tui")
    for bin in "${bins[@]}"; do
        local src="$INSTALL_DIR/current/bin/$bin"
        local dest="$BIN_DIR/$bin"
        if [[ -e "$src" ]]; then
            ln -sf "$src" "$dest"
        fi
    done
}

# Write state.json atomically (write to .tmp, rename).
write_state_json() {
    local installed="$1" previous="$2" channel="$3"
    local now
    now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    local prev_field=""
    if [[ -n "$previous" ]]; then
        prev_field=",
  \"previousVersion\": \"$previous\""
    else
        prev_field=",
  \"previousVersion\": null"
    fi

    cat > "$INSTALL_DIR/state.json.tmp" <<EOF
{
  "schemaVersion": 2,
  "installedVersion": "$installed"$prev_field,
  "channel": "$channel",
  "lastCheckAt": null,
  "latestKnownByChannel": { "stable": null, "beta": null },
  "installSource": "curl-installer",
  "updatedAt": "$now"
}
EOF
    mv -f "$INSTALL_DIR/state.json.tmp" "$INSTALL_DIR/state.json"
}

# Prune old versions, keeping current + previousVersion. Best-effort: never
# fails the install. Skips if state.json is unreadable.
prune_old_versions() {
    if [[ ! -f "$INSTALL_DIR/state.json" ]]; then
        return 0
    fi

    local keep_current keep_previous
    keep_current="$(node -p "
        try { require('$INSTALL_DIR/state.json').installedVersion || ''; }
        catch (e) { ''; }
    " 2>/dev/null || echo "")"
    keep_previous="$(node -p "
        try { require('$INSTALL_DIR/state.json').previousVersion || ''; }
        catch (e) { ''; }
    " 2>/dev/null || echo "")"

    if [[ -z "$keep_current" ]]; then
        return 0
    fi

    local versions_dir="$INSTALL_DIR/versions"
    [[ -d "$versions_dir" ]] || return 0

    local entry name
    for entry in "$versions_dir"/*/; do
        [[ -d "$entry" ]] || continue
        name="$(basename "$entry")"
        case "$name" in
            "$keep_current"|"$keep_previous") continue ;;
            .staging-*) continue ;;  # in-flight; let the updater own it
        esac
        echo "    Removing old version: $name"
        rm -rf "$entry"
    done
}

path_contains_bin_dir() {
    case ":$PATH:" in
        *":$BIN_DIR:"*) return 0 ;;
        *)              return 1 ;;
    esac
}

shell_config_file() {
    local shell_name
    shell_name="$(basename "${SHELL:-/bin/bash}")"
    case "$shell_name" in
        zsh)  echo "$HOME/.zshrc" ;;
        fish) echo "$HOME/.config/fish/config.fish" ;;
        *)    echo "$HOME/.bashrc" ;;
    esac
}

uninstall() {
    echo ""
    echo "  Nimbreth Uninstaller"
    echo "  ────────────────────"
    echo ""

    local bins=("nimbreth" "nimbreth-cli" "nimbreth-tui")
    local removed=false

    for bin in "${bins[@]}"; do
        local link="$BIN_DIR/$bin"
        if [[ -L "$link" || -e "$link" ]]; then
            rm -f "$link"
            echo "  Removed $link"
            removed=true
        fi
    done

    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        echo "  Removed $INSTALL_DIR"
        removed=true
    fi

    if [[ "$removed" == true ]]; then
        echo ""
        echo "  Uninstall complete."
    else
        echo "  Nothing to remove — nimbreth is not installed at the expected paths."
    fi

    local config_dir="$HOME/.config/nimbreth"
    if [[ -d "$config_dir" ]]; then
        echo ""
        echo "  Note: app config at $config_dir was preserved."
        echo "  Remove it manually if you no longer need it:"
        echo ""
        echo "    rm -rf $config_dir"
    fi

    echo ""
    exit 0
}

# ── Main ─────────────────────────────────────────────────────────────────────

# Allow callers (tests) to source this file purely for its helper functions.
if [[ "${NIMBRETH_INSTALL_LIB_ONLY:-0}" == "1" ]]; then
    return 0 2>/dev/null || exit 0
fi

if [[ "$UNINSTALL" == true ]]; then
    uninstall
fi

detect_platform
resolve_version

CHANNEL="$(infer_channel "$VERSION")"
RELEASE_NAME="nimbreth-${VERSION}-${PLATFORM}-${ARCH}"
BASE_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}"
TARBALL_URL="${BASE_URL}/${RELEASE_NAME}.tar.gz"
CHECKSUM_URL="${BASE_URL}/${RELEASE_NAME}.sha256"

echo ""
echo "  Nimbreth Installer"
echo "  ──────────────────"
echo "  Version:      ${VERSION} (${CHANNEL})"
echo "  Platform:     ${PLATFORM}-${ARCH}"
echo "  Install to:   ${INSTALL_DIR}"
echo "  Bin dir:      ${BIN_DIR}"
echo ""

# Capture the previously-installed version (if any) so state.json's
# previousVersion can support `nimbreth update --rollback`.
PREVIOUS_VERSION=""
if [[ -f "$INSTALL_DIR/state.json" ]]; then
    PREVIOUS_VERSION="$(node -p "
        try {
            const state = require('$INSTALL_DIR/state.json');
            state.schemaVersion === 2 && typeof state.installedVersion === 'string'
                ? state.installedVersion
                : '';
        }
        catch (e) { ''; }
    " 2>/dev/null || echo "")"
fi

# Download to a temp directory
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "==> Downloading ${RELEASE_NAME}.tar.gz..."
download "$TARBALL_URL" "$TMP_DIR/${RELEASE_NAME}.tar.gz"

echo "==> Downloading checksum..."
download "$CHECKSUM_URL" "$TMP_DIR/${RELEASE_NAME}.sha256" 2>/dev/null || true

echo "==> Verifying checksum..."
verify_checksum "$TMP_DIR/${RELEASE_NAME}.tar.gz" "$TMP_DIR/${RELEASE_NAME}.sha256"

# Extract to staging, then atomically promote to versions/<ver>/.
mkdir -p "$INSTALL_DIR/versions"
STAGING_DIR="$INSTALL_DIR/versions/.staging-${VERSION}.$$"
VERSION_DIR="$INSTALL_DIR/versions/${VERSION}"

if [[ -d "$STAGING_DIR" ]]; then
    rm -rf "$STAGING_DIR"
fi

echo "==> Extracting to staging..."
mkdir -p "$STAGING_DIR"
tar -xzf "$TMP_DIR/${RELEASE_NAME}.tar.gz" -C "$STAGING_DIR" --strip-components=1

# If this exact version already lives in versions/, replace it (re-install).
if [[ -d "$VERSION_DIR" ]]; then
    echo "==> Replacing existing $VERSION_DIR..."
    rm -rf "$VERSION_DIR"
fi
mv "$STAGING_DIR" "$VERSION_DIR"

# macOS: strip quarantine attributes so Gatekeeper doesn't block ad-hoc signed
# binaries on first launch. No-op when nothing is quarantined.
if [[ "$PLATFORM" == "darwin" ]] && command -v xattr &>/dev/null; then
    xattr -dr com.apple.quarantine "$VERSION_DIR" 2>/dev/null || true
fi

echo "==> Activating ${VERSION}..."
swap_current_symlink "versions/${VERSION}"

echo "==> Refreshing symlinks in ${BIN_DIR}..."
create_symlinks

echo "==> Writing state.json..."
write_state_json "$VERSION" "$PREVIOUS_VERSION" "$CHANNEL"

echo "==> Pruning old versions..."
prune_old_versions

echo ""
echo "  Installation complete!"
echo ""

if ! path_contains_bin_dir; then
    CONFIG_FILE="$(shell_config_file)"
    echo "  ${BIN_DIR} is not in your PATH."
    echo "  Add it by running:"
    echo ""
    echo "    echo 'export PATH=\"${BIN_DIR}:\$PATH\"' >> ${CONFIG_FILE}"
    echo "    source ${CONFIG_FILE}"
    echo ""
fi

echo "  Get started:"
echo ""
echo "    nimbreth --help"
echo "    nimbreth vault init ~/my-vault"
echo "    nimbreth                        # launch interactive TUI"
echo ""
echo "  To upgrade later, run:"
echo ""
echo "    nimbreth update"
echo ""
