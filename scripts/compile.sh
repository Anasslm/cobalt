#!/usr/bin/env bash
#set -euo pipefail

##COBALT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
##
##BENDER_SOURCES="$(bender sources --raw)"
##
##export CVA6_REPO_DIR="$(printf '%s\n' "$BENDER_SOURCES" | grep -m1 '/.bender/git/checkouts/ariane-' | sed 's|^[[:space:]]*"||; s|/core/include".*$||')"
##
##if [[ ! -d "$CVA6_REPO_DIR" ]]; then
##    echo "ERROR: CVA6 checkout not found."
##    echo "Run: bender update"
##    exit 1
##fi
##


export CVA6_REPO_DIR="$PWD/rtl/third_party/cva6"
export HPDCACHE_DIR="$CVA6_REPO_DIR/core/cache_subsystem/hpdcache"
export TARGET_CFG="cv64a6_imafdc_sv39"

export VERILATOR="$(command -v verilator)"

"$VERILATOR" \
    --binary \
    --trace \
    --Wno-fatal \
     --trace-structs \
    -Wno-BLKANDNBLK \
    --top-module cobalt_tb \
    -f filelists/rtl.f \
    -f filelists/testbench.f \
    verif/tb/cobalt_tb.sv

