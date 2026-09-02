#!/bin/bash

# ============================================================
# Build script for the three‑stage bootloader
# Usage: ./build.sh [run|clean]
#   (no args)        – assemble and create os.img
#   run              – assemble, create os.img, and launch QEMU
#   clean            – remove generated files
# ============================================================

set -e  # exit on error

# ---- Configuration ----
NASM="nasm"
QEMU="qemu-system-x86_64"
IMAGE="os.img"
BOOT_BIN="boot.bin"
INIT_BIN="init.bin"
MAIN_BIN="main.bin"

# ---- Colours for pretty output ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ---- Helper functions ----
error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

check_dependencies() {
    if ! command -v "$NASM" &>/dev/null; then
        error "NASM not found. Please install it (e.g., 'sudo apt install nasm')."
    fi
}

assemble() {
    info "Assembling boot.asm ..."
    $NASM -f bin boot.asm -o "$BOOT_BIN" || error "Failed to assemble boot.asm"

    info "Assembling init.asm ..."
    $NASM -f bin init.asm -o "$INIT_BIN" || error "Failed to assemble init.asm"

    info "Assembling main.asm ..."
    $NASM -f bin main.asm -o "$MAIN_BIN" || error "Failed to assemble main.asm"
}

create_image() {
    info "Creating disk image: $IMAGE"
    cat "$BOOT_BIN" "$INIT_BIN" "$MAIN_BIN" > "$IMAGE"
    # Optionally pad the image to 1.44 MB (floppy size)
    # dd if=/dev/zero of="$IMAGE" bs=512 seek=3 count=2877 2>/dev/null
    info "Image created successfully (size: $(du -h "$IMAGE" | cut -f1))."
}

run_qemu() {
    if ! command -v "$QEMU" &>/dev/null; then
        warn "QEMU not found. Skipping emulation."
        return
    fi
    info "Launching QEMU ..."
    $QEMU -drive format=raw,file="$IMAGE"
}

clean() {
    info "Cleaning up ..."
    rm -f "$BOOT_BIN" "$INIT_BIN" "$MAIN_BIN" "$IMAGE"
    info "All generated files removed."
}

usage() {
    cat <<EOF
Usage: $0 [OPTION]

Options:
  (no args)   – Assemble and create the disk image (os.img)
  run         – Assemble, create disk image, and run in QEMU
  clean       – Remove all generated binaries and the image
  -h, --help  – Show this help message

Examples:
  ./build.sh         # just build
  ./build.sh run     # build and run
  ./build.sh clean   # clean up
EOF
}

# ---- Main script ----
case "$1" in
    "" )
        check_dependencies
        assemble
        create_image
        info "Build complete. You can run the image with: $QEMU -drive format=raw,file=$IMAGE"
        ;;
    run )
        check_dependencies
        assemble
        create_image
        run_qemu
        ;;
    clean )
        clean
        ;;
    -h | --help )
        usage
        ;;
    * )
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
esac