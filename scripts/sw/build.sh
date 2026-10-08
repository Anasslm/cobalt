#!/usr/bin/env bash

set -euo pipefail

COBALT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

RISCV_PREFIX="riscv64-unknown-elf"

TEST="${1:-hello}"
# used this to handle both .s and .c 
TEST_DIR="$COBALT_ROOT/firmware/tests"

if [[ -f "$TEST_DIR/${TEST}.c" ]]; then
    SRC="$TEST_DIR/${TEST}.c"
    START="$TEST_DIR/start.S"
    IS_C_TEST=true
elif [[ -f "$TEST_DIR/${TEST}.S" ]]; then
    SRC="$TEST_DIR/${TEST}.S"
    START=""
    IS_C_TEST=false
else
    echo "ERROR: test '$TEST' not found."
    exit 1
fi
# path to build directory
BUILD_DIR="$COBALT_ROOT/firmware/build/${TEST}"
# path to ram linker file
LINKER="$COBALT_ROOT/firmware/linker/cobalt_ram.ld"

mkdir -p "$BUILD_DIR"

echo "========================================"
echo "Building Cobalt firmware: $TEST"
echo "========================================"

    
if [[ "$IS_C_TEST" == true ]]; then

    echo "Source: C"
    echo "  $SRC"
    echo "  $START"

    "${RISCV_PREFIX}-gcc" \
        -march=rv64imafdc \
        -mabi=lp64d \
        -ffreestanding \
        -fno-builtin \
        -nostdlib \
        -nostartfiles \
        -nodefaultlibs \
        -mcmodel=medany \
        "$COBALT_ROOT/firmware/lib/cobalt_printf.c" \
        "$COBALT_ROOT/firmware/lib/uart.c" \
        -I"$COBALT_ROOT/firmware/include" \
        -T "$LINKER" \
        -o "$BUILD_DIR/${TEST}.elf" \
        "$START" \
        "$SRC"

else

    echo "Source: Assembly"
    echo "  $SRC"

    "${RISCV_PREFIX}-gcc" \
        -march=rv64imafdc \
        -mabi=lp64d \
        -nostdlib \
        -nostartfiles \
        -nodefaultlibs \
        -T "$LINKER" \
        -o "$BUILD_DIR/${TEST}.elf" \
        "$SRC"

fi

"${RISCV_PREFIX}-objcopy" \
    -O binary \
    "$BUILD_DIR/${TEST}.elf" \
    "$BUILD_DIR/${TEST}.bin"

"${RISCV_PREFIX}-objdump" \
    -d \
    "$BUILD_DIR/${TEST}.elf" \
    > "$BUILD_DIR/${TEST}.objdump"

"${RISCV_PREFIX}-readelf" \
    -a \
    "$BUILD_DIR/${TEST}.elf" \
    > "$BUILD_DIR/${TEST}.readelf"

python3 \
    "$COBALT_ROOT/scripts/sw/bin_to_mem.py" \
    "$BUILD_DIR/${TEST}.bin" \
    "$COBALT_ROOT/verif/tb/sram_program.mem"

echo
echo "Firmware build complete:"
echo "  ELF : $BUILD_DIR/${TEST}.elf"
echo "  BIN : $BUILD_DIR/${TEST}.bin"
echo "  MEM : $COBALT_ROOT/verif/tb/sram_program.mem"