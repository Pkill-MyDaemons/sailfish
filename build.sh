#!/bin/bash
# Sailfish ISO build script
# Requires: lorax, pykickstart, git — run on Fedora 42
# Usage: sudo ./build.sh [--cache-dir /path] [--resultdir /path]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTDIR="${RESULTDIR:-/tmp/sailfish-iso}"
CACHEDIR="${CACHEDIR:-/tmp/sailfish-cache}"
KS="$SCRIPT_DIR/sailfish.ks"
LOGDIR="$RESULTDIR/logs"
VOLID="Sailfish-42-x86_64"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[sailfish]${NC} $*"; }
warn() { echo -e "${YELLOW}[sailfish]${NC} $*"; }
die()  { echo -e "${RED}[sailfish ERROR]${NC} $*"; exit 1; }

# --- Preflight ---------------------------------------------------------------
[[ "$(id -u)" -eq 0 ]] || die "Must run as root: sudo ./build.sh"
[[ -f "$KS" ]] || die "Kickstart not found: $KS"

log "Checking build dependencies"
MISSING=()
for pkg in lorax pykickstart git wget unzip; do
  rpm -q "$pkg" &>/dev/null || MISSING+=("$pkg")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  warn "Installing missing build deps: ${MISSING[*]}"
  dnf install -y "${MISSING[@]}"
fi

# --- Validate kickstart -------------------------------------------------------
log "Validating kickstart"
ksvalidator "$KS" || die "Kickstart validation failed"

# --- Prepare output dirs ------------------------------------------------------
mkdir -p "$RESULTDIR" "$CACHEDIR" "$LOGDIR"

# Bundle firstboot script into the kickstart accessible location
log "Preparing build artifacts"
cp "$SCRIPT_DIR/scripts/firstboot.sh" /tmp/sailfish-firstboot.sh
chmod +x /tmp/sailfish-firstboot.sh

# --- Run livemedia-creator ---------------------------------------------------
log "Starting ISO build (this takes 20-60 minutes depending on your connection)"
log "Output: $RESULTDIR"
log "Logs:   $LOGDIR"

livemedia-creator \
  --make-iso \
  --ks="$KS" \
  --tmp="$CACHEDIR" \
  --resultdir="$RESULTDIR" \
  --logfile="$LOGDIR/build.log" \
  --volid="$VOLID" \
  --iso-name="Sailfish-42-x86_64.iso" \
  --no-virt \
  --project="Sailfish" \
  --releasever=42 \
  --macboot \
  2>&1 | tee "$LOGDIR/livemedia-creator.log"

# --- Verify output -----------------------------------------------------------
ISO="$RESULTDIR/Sailfish-42-x86_64.iso"
if [[ -f "$ISO" ]]; then
  SIZE=$(du -sh "$ISO" | cut -f1)
  SHA256=$(sha256sum "$ISO" | cut -d' ' -f1)
  log "Build successful!"
  log "ISO:    $ISO ($SIZE)"
  log "SHA256: $SHA256"
  echo "$SHA256  Sailfish-42-x86_64.iso" > "$RESULTDIR/SHA256SUMS"
  log ""
  log "Flash to USB:  sudo dd if=$ISO of=/dev/sdX bs=4M status=progress oflag=sync"
  log "               (replace /dev/sdX with your USB device)"
else
  die "Build failed — ISO not found. Check logs in $LOGDIR"
fi
