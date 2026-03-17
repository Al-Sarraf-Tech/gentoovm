#!/bin/bash
set -euo pipefail

# GentooVM ISO Reassembly Script
# Downloads are split due to GitHub's 2GB file size limit.
# This script safely reassembles and verifies the ISO.

BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BOLD}GentooVM ISO Reassembly${NC}"
echo ""

# Check parts exist
PARTS=$(ls gentoovm.iso.part.* 2>/dev/null | sort)
if [ -z "$PARTS" ]; then
    echo -e "${RED}Error: No gentoovm.iso.part.* files found in current directory.${NC}"
    echo "Download all part files into the same directory and run this script again."
    exit 1
fi

PART_COUNT=$(echo "$PARTS" | wc -l)
echo "Found $PART_COUNT parts:"
for p in $PARTS; do
    echo "  $(ls -lh "$p" | awk '{print $5, $9}')"
done
echo ""

# Reassemble
echo -e "${BOLD}Reassembling...${NC}"
cat gentoovm.iso.part.* > gentoovm.iso
echo "  Created: gentoovm.iso ($(du -h gentoovm.iso | cut -f1))"
echo ""

# Verify
echo -e "${BOLD}Verifying integrity...${NC}"
if [ -f gentoovm.iso.sha256 ]; then
    if sha256sum -c gentoovm.iso.sha256; then
        echo ""
        echo -e "${GREEN}ISO verified successfully!${NC}"
    else
        echo ""
        echo -e "${RED}CHECKSUM MISMATCH — the ISO may be corrupted. Re-download all parts.${NC}"
        exit 1
    fi
else
    echo "  Warning: gentoovm.iso.sha256 not found — cannot verify. Download it from the release page."
fi

echo ""
echo -e "${BOLD}Done.${NC} You can now:"
echo "  1. Delete the part files:  rm gentoovm.iso.part.*"
echo "  2. Boot the ISO — see README.md or GETTING-STARTED.md for instructions"
