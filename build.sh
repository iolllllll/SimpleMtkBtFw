#!/bin/bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

INSTALL_MODE=0
for arg in "$@"; do
    case "$arg" in
        --install)
            INSTALL_MODE=1
            ;;
        -h|--help)
            echo "Usage: ./build.sh [--install]"
            echo ""
            echo "Builds all kexts in one step:"
            echo "  - SimpleMtkBtFw.kext (MediaTek firmware loader for MT7921 / MT7922 / MT7925)"
            echo "  - SimpleMtkBtPatcher.kext (Lilu patcher for generic dongle mode)"
            echo "  - BlueToolFixup.kext (MediaTek native whitelist patch for macOS 15 Sequoia & 26 Tahoe)"
            echo ""
            echo "Options:"
            echo "  --install    Automatically copy built kexts to mounted EFI/OC/Kexts and"
            echo "               install firmware to /etc/bluetool"
            exit 0
            ;;
    esac
done

echo "=================================================="
echo "  SimpleMtkBtFw + BlueToolFixup All-In-One Build  "
echo "=================================================="

# 1. Bootstrap SDKs
echo "==> Step 1/4: Checking SDKs and Lilu dependencies..."
./scripts/bootstrap.sh

# 2. Build SimpleMtkBtFw & SimpleMtkBtPatcher
echo "==> Step 2/4: Building SimpleMtkBtFw & SimpleMtkBtPatcher..."
for SCHEME in SimpleMtkBtFw SimpleMtkBtPatcher; do
    echo "  -> Building $SCHEME (Release)..."
    xcodebuild -project SimpleMtkBtFw.xcodeproj -scheme "$SCHEME" \
        -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO build > /dev/null
done

# 3. Build Patched BlueToolFixup (MediaTek Sequoia & Tahoe)
echo "==> Step 3/4: Building patched BlueToolFixup (MediaTek native driver patch)..."
export MKS="$HERE/MacKernelSDK"
export LILU="$HERE/Lilu.kext"
"$HERE/BlueToolFixup-MediaTek/build.sh" > /dev/null

# 4. Assemble output into dist/
echo "==> Step 4/4: Packaging artifacts into dist/..."
DIST="$HERE/dist"
rm -rf "$DIST" && mkdir -p "$DIST/Kexts" "$DIST/Firmware"

cp -R "build/Build/Products/Release/SimpleMtkBtFw.kext" "$DIST/Kexts/"
cp -R "build/Build/Products/Release/SimpleMtkBtPatcher.kext" "$DIST/Kexts/"
cp -R "$HERE/BlueToolFixup-MediaTek/build-work/src/build/Products/Release/BlueToolFixup.kext" "$DIST/Kexts/"
cp -R "$HERE/Lilu.kext" "$DIST/Kexts/"
cp "$HERE/SimpleMtkBtFw/fw/BT_RAM_CODE_MT7922_1_1_hdr.bin" "$DIST/Firmware/"
cp "$HERE/SimpleMtkBtFw/fw/BT_RAM_CODE_MT7925_1_1_hdr.bin" "$DIST/Firmware/"
cp "$HERE/docs/config-snippet.plist" "$DIST/"
cp "$HERE/docs/INSTALL.txt" "$DIST/"

echo ""
echo "=================================================="
echo "  BUILD SUCCEEDED! Artifacts ready in dist/       "
echo "=================================================="
echo "Kexts in $DIST/Kexts:"
ls -1 "$DIST/Kexts"
echo ""
echo "Firmware in $DIST/Firmware:"
ls -1 "$DIST/Firmware"

if [ "$INSTALL_MODE" -eq 1 ]; then
    echo ""
    echo "==> Performing automatic installation (--install)..."
    EFI_DIR=""
    for d in /Volumes/*/EFI/OC/Kexts; do
        if [ -d "$d" ]; then
            EFI_DIR="$d"
            break
        fi
    done

    if [ -n "$EFI_DIR" ]; then
        echo "Copying kexts to $EFI_DIR..."
        cp -R "$DIST/Kexts/SimpleMtkBtFw.kext" "$EFI_DIR/"
        cp -R "$DIST/Kexts/BlueToolFixup.kext" "$EFI_DIR/"
        echo "  [OK] Installed SimpleMtkBtFw.kext and BlueToolFixup.kext to $EFI_DIR"
    else
        echo "  [!] No mounted OpenCore EFI partition found in /Volumes."
        echo "      Copy kexts from $DIST/Kexts/ manually to your EFI/OC/Kexts/."
    fi

    echo "Installing firmware to /etc/bluetool..."
    sudo mkdir -p /etc/bluetool
    sudo cp "$DIST/Firmware/BT_RAM_CODE_MT7922_1_1_hdr.bin" /etc/bluetool/
    sudo chown root:wheel /etc/bluetool/BT_RAM_CODE_MT7922_1_1_hdr.bin
    sudo chmod 644 /etc/bluetool/BT_RAM_CODE_MT7922_1_1_hdr.bin
    echo "  [OK] Installed /etc/bluetool/BT_RAM_CODE_MT7922_1_1_hdr.bin"
    echo ""
    echo "Installation complete! Please cold reboot (power down completely for 15s)."
fi
