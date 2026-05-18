#!/usr/bin/env sh
# flart installer.
#
# Downloads the latest (or pinned) flart binary for your OS/arch from
# GitHub Releases and drops it in ~/.local/bin/flart (override with
# FLART_INSTALL_DIR). Idempotent — re-running overwrites the previous
# binary at the same path. The Claude Code hook is NOT installed
# automatically; once flart is on $PATH, run `flart init` yourself.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/MelihCevhertas/flart/main/install.sh | sh
#
# Environment overrides:
#   FLART_VERSION=v0.1.0           # default: latest
#   FLART_INSTALL_DIR=$HOME/bin    # default: $HOME/.local/bin
set -e

REPO="MelihCevhertas/flart"
VERSION="${FLART_VERSION:-latest}"
INSTALL_DIR="${FLART_INSTALL_DIR:-$HOME/.local/bin}"

# ---- OS / arch detection ----------------------------------------------------
uname_s="$(uname -s)"
case "$uname_s" in
  Darwin) os="macos" ;;
  Linux)  os="linux" ;;
  *) echo "flart installer: unsupported OS '$uname_s'." >&2
     echo "Supported: macOS, Linux. See README for build-from-source." >&2
     exit 1 ;;
esac

uname_m="$(uname -m)"
case "$uname_m" in
  arm64|aarch64)
    if [ "$os" = "linux" ]; then
      echo "flart installer: Linux arm64 binaries not yet published (v1.1 backlog)." >&2
      echo "Build from source: see README.md." >&2
      exit 1
    fi
    arch="arm64" ;;
  x86_64|amd64) arch="x64" ;;
  *) echo "flart installer: unsupported arch '$uname_m'." >&2
     exit 1 ;;
esac

asset="flart-${os}-${arch}"

if [ "$VERSION" = "latest" ]; then
  base_url="https://github.com/$REPO/releases/latest/download"
else
  base_url="https://github.com/$REPO/releases/download/$VERSION"
fi

# ---- jq dependency (best-effort warning, not fatal) -------------------------
if ! command -v jq >/dev/null 2>&1; then
  echo "Note: 'jq' is required for the Claude Code hook ('flart init')."
  case "$os" in
    macos) echo "  Install: brew install jq" ;;
    linux) echo "  Install: apt install jq  (Debian/Ubuntu) — or your distro's package manager" ;;
  esac
  echo ""
fi

# ---- Download + install -----------------------------------------------------
mkdir -p "$INSTALL_DIR"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

echo "→ Downloading $asset from $base_url"
if ! curl -fsSL "$base_url/$asset" -o "$tmp"; then
  echo "flart installer: download failed." >&2
  echo "  URL: $base_url/$asset" >&2
  echo "  Check your network or try FLART_VERSION=<known tag>." >&2
  exit 1
fi
chmod +x "$tmp"

target="$INSTALL_DIR/flart"
mv -f "$tmp" "$target"
trap - EXIT
echo "→ Installed $target"

# ---- macOS quarantine -------------------------------------------------------
# First run on macOS may show 'developer cannot be verified'. Clear the
# quarantine attribute proactively so the binary launches without a
# Right-click → Open dance.
if [ "$os" = "macos" ]; then
  xattr -d com.apple.quarantine "$target" >/dev/null 2>&1 || true
fi

# ---- PATH check -------------------------------------------------------------
case ":$PATH:" in
  *":$INSTALL_DIR:"*)
    ;;
  *)
    echo ""
    echo "Note: $INSTALL_DIR is not on \$PATH."
    shell_name="${SHELL##*/}"
    case "$shell_name" in
      zsh)
        echo "  Add to ~/.zshrc:  export PATH=\"$INSTALL_DIR:\$PATH\""
        echo "  Then reload:      source ~/.zshrc" ;;
      bash)
        echo "  Add to ~/.bashrc: export PATH=\"$INSTALL_DIR:\$PATH\""
        echo "  Then reload:      source ~/.bashrc" ;;
      fish)
        echo "  Add to ~/.config/fish/config.fish:  set -gx PATH $INSTALL_DIR \$PATH" ;;
      *)
        echo "  Add $INSTALL_DIR to your shell's PATH and reopen the shell." ;;
    esac
    ;;
esac

# ---- Smoke + next steps -----------------------------------------------------
echo ""
echo "Verify:"
"$target" version || true

echo ""
echo "Next steps:"
echo "  cd <your-project>"
echo "  flart init --check    # see what's missing (PATH, jq, hook, CLAUDE.md)"
echo "  flart init            # install the Claude Code hook (with confirmation prompt)"
echo ""
echo "If macOS Gatekeeper blocks the binary on first run:"
echo "  xattr -d com.apple.quarantine $target"
echo "  # …or right-click → Open in Finder once."
