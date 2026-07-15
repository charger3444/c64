#!/usr/bin/env bash
# Builds FIDATI. for the Commodore 64.
#
# Requires cc65 (cl65/ca65/ld65). On Debian/Ubuntu:
#   sudo apt-get install cc65
#
# Usage: ./build.sh
# Output: build/fidati.prg

set -euo pipefail
cd "$(dirname "$0")"

mkdir -p build
cl65 -t none -C src/c64-fidati.cfg -o build/fidati.prg src/fidati.s

echo "Built build/fidati.prg"
