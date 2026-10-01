#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FW_DIR="$SCRIPT_DIR/../assets/firmware/blackmagic_s2"

echo "=== Black Magic Probe ESP32-S2 Auto-Flasher ==="

find_port() {
    for p in /dev/cu.usbmodem* /dev/cu.usbserial*; do
        if [ -e "$p" ]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

PORT=$(find_port || true)

if [ -z "$PORT" ]; then
    echo "Waiting for ESP32-S2 devboard to be plugged in..."
    echo "(If not detected, hold the BOOT button on the devboard while plugging in USB)"
    while [ -z "$PORT" ]; do
        sleep 1
        PORT=$(find_port || true)
    done
fi

echo "Detected ESP32 device at: $PORT"
echo "Beginning Black Magic Probe flash..."

/opt/homebrew/bin/esptool.py -p "$PORT" -b 460800 \
    --before default_reset --after hard_reset \
    --chip esp32s2 write_flash \
    --flash_mode dio --flash_freq 80m --flash_size 4MB \
    0x1000 "$FW_DIR/bootloader.bin" \
    0x8000 "$FW_DIR/partition-table.bin" \
    0x10000 "$FW_DIR/blackmagic.bin"

echo ""
echo "=== Black Magic Probe Flashed Successfully! ==="
echo "The ESP32-S2 devboard will now reboot and enumerate as a Black Magic Probe."
