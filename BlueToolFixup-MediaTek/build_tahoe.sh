#!/bin/bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SRC="$HERE/src"

echo "=== Building MediaTek BlueToolFixup for macOS Tahoe ==="
cd "$SRC"

# Set up SDK links
rm -rf MacKernelSDK Lilu.kext
ln -s "$ROOT/MacKernelSDK" MacKernelSDK
cp -R "$ROOT/Lilu.kext" Lilu.kext

# Build Release
xcodebuild -project BrcmPatchRAM.xcodeproj -scheme BlueToolFixup -configuration Release \
    CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" build

BUILT_KEXT="$SRC/build/Products/Release/BlueToolFixup.kext"
if [ ! -d "$BUILT_KEXT" ]; then
    echo "ERROR: Build failed, $BUILT_KEXT does not exist" >&2
    exit 1
fi
echo "SUCCESS: Built $BUILT_KEXT"

# Copy to OpenCore EFI if mounted
EFI_DIR=""
for d in /Volumes/*/EFI/OC/Kexts; do
    if [ -d "$d" ]; then
        EFI_DIR="$d"
        break
    fi
done

if [ -n "$EFI_DIR" ]; then
    echo "Installing to EFI: $EFI_DIR"
    cp -R "$BUILT_KEXT" "$EFI_DIR/"
    echo "Installed BlueToolFixup.kext to $EFI_DIR"
else
    echo "OpenCore EFI not found in /Volumes. Copy $BUILT_KEXT to EFI/OC/Kexts manually."
fi

# Install firmware to /etc/bluetool
echo "=== Installing firmware to /etc/bluetool ==="
FW=""
for f in "$ROOT/SimpleMtkBtFw/fw/BT_RAM_CODE_MT7925_1_1_hdr.bin" \
         /Volumes/*/BT_RAM_CODE_MT7922_1_1_hdr.bin; do
    if [ -f "$f" ]; then
        FW="$f"
        break
    fi
done

if [ -n "$FW" ]; then
    sudo mkdir -p /etc/bluetool
    sudo cp "$FW" /etc/bluetool/BT_RAM_CODE_MT7922_1_1_hdr.bin
    sudo chown root:wheel /etc/bluetool/BT_RAM_CODE_MT7922_1_1_hdr.bin
    sudo chmod 644 /etc/bluetool/BT_RAM_CODE_MT7922_1_1_hdr.bin
    echo "Installed $(basename "$FW") to /etc/bluetool/BT_RAM_CODE_MT7922_1_1_hdr.bin"
    ls -la /etc/bluetool/
else
    echo "WARNING: Firmware file not found."
fi

echo ""
echo "=== ALL DONE! ==="
echo "Now shut down the PC completely, wait 10 seconds, and turn it on."
