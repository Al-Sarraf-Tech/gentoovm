#!/usr/bin/env bash
set -euo pipefail

# Update the torrent seed with a new ISO release
# Usage: ./scripts/update-torrent-seed.sh [version]
# Example: ./scripts/update-torrent-seed.sh 1.1

VERSION="${1:-}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ISO_SRC="$REPO_DIR/iso/gentoovm.iso"
SEED_DIR="/docker/pirates/gentoo"
COMPLETE_DIR="/docker/pirates/complete"
TRANS_AUTH="jalsarraf:ffxi123\$"

if [ ! -f "$ISO_SRC" ]; then
    echo "Error: ISO not found at $ISO_SRC"
    exit 1
fi

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.1"
    exit 1
fi

echo "=== GentooVM Torrent Seed Update ==="
echo "Version: $VERSION"
echo "ISO: $ISO_SRC ($(du -h "$ISO_SRC" | cut -f1))"
echo ""

# 1. Remove old torrents from transmission
echo "Removing old torrents from transmission..."
OLD_IDS=$(transmission-remote -n "$TRANS_AUTH" -l 2>/dev/null | grep "gentoovm" | awk '{print $1}' | grep -E '^[0-9]+$')
for id in $OLD_IDS; do
    echo "  Removing torrent ID $id"
    transmission-remote -n "$TRANS_AUTH" -t "$id" --remove 2>/dev/null || true
done

# 2. Clean old files
echo "Cleaning old files..."
rm -f "$COMPLETE_DIR"/gentoovm.iso
rm -f "$SEED_DIR"/gentoovm-*.torrent

# 3. Create new torrent
echo "Creating torrent for v${VERSION}..."
command -v transmission-create &>/dev/null || { echo "Error: transmission-create not found"; exit 1; }

transmission-create \
    -o "$SEED_DIR/gentoovm-${VERSION}.torrent" \
    -c "GentooVM ${VERSION} - Custom Gentoo Linux for QEMU/KVM. https://github.com/jalsarraf0/gentoovm" \
    -t udp://tracker.opentrackr.org:1337/announce \
    -t udp://tracker.openbittorrent.com:6969/announce \
    -t udp://open.stealth.si:80/announce \
    -t udp://tracker.torrent.eu.org:451/announce \
    -t udp://exodus.desync.com:6969/announce \
    -t udp://open.demonii.com:1337/announce \
    "$ISO_SRC" 2>&1

# 4. Copy ISO to seed directory
echo "Copying ISO to seed directory..."
cp "$ISO_SRC" "$COMPLETE_DIR/gentoovm.iso"

# 5. Copy torrent and magnet link to repo
cp "$SEED_DIR/gentoovm-${VERSION}.torrent" "$REPO_DIR/iso/"
transmission-show --magnet "$SEED_DIR/gentoovm-${VERSION}.torrent" > "$REPO_DIR/iso/MAGNET_LINK.txt"
echo "Magnet link: $(cat "$REPO_DIR/iso/MAGNET_LINK.txt")"

# 6. Add to transmission
echo "Adding torrent to transmission..."
transmission-remote -n "$TRANS_AUTH" \
    -a "$SEED_DIR/gentoovm-${VERSION}.torrent" \
    --download-dir /data/completed 2>&1

sleep 3
transmission-remote -n "$TRANS_AUTH" -l 2>/dev/null | grep "gentoovm"

# 7. Wait for verification
echo "Verifying..."
for i in $(seq 1 30); do
    sleep 5
    STATUS=$(transmission-remote -n "$TRANS_AUTH" -l 2>/dev/null | grep "gentoovm")
    echo "  $STATUS"
    echo "$STATUS" | grep -q "100%" && break
done

# 8. Start seeding
NEW_ID=$(transmission-remote -n "$TRANS_AUTH" -l 2>/dev/null | grep "gentoovm" | awk '{print $1}' | grep -E '^[0-9]+$' | tail -1)
[ -n "$NEW_ID" ] && transmission-remote -n "$TRANS_AUTH" -t "$NEW_ID" -s 2>/dev/null

echo ""
echo "=== Done ==="
echo "Torrent: $SEED_DIR/gentoovm-${VERSION}.torrent"
echo "Seeding: $(transmission-remote -n "$TRANS_AUTH" -l 2>/dev/null | grep gentoovm)"
echo ""
echo "Next steps:"
echo "  1. git add iso/gentoovm-${VERSION}.torrent iso/MAGNET_LINK.txt"
echo "  2. git commit and push"
echo "  3. git tag v${VERSION} && git push origin v${VERSION}"
echo "  4. Upload ISO parts to the GitHub release"
