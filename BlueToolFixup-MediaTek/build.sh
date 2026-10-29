#!/bin/bash
# Reproducible build of the MediaTek-whitelist BlueToolFixup.
# Requirements: Xcode, git, a MacKernelSDK checkout and the Lilu 1.7.x DEBUG kext (for its SDK headers).
#   MKS=/path/to/MacKernelSDK LILU=/path/to/Lilu.kext ./build.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

MKS="${MKS:-$ROOT/MacKernelSDK}"
LILU="${LILU:-$ROOT/Lilu.kext}"

if [ ! -d "$MKS" ]; then
    echo "ERROR: MacKernelSDK not found at $MKS. Set MKS=/path/to/MacKernelSDK" >&2
    exit 1
fi
if [ ! -d "$LILU" ]; then
    echo "ERROR: Lilu.kext not found at $LILU. Set LILU=/path/to/Lilu.kext" >&2
    exit 1
fi

WORK="${WORK:-$HERE/build-work}"
UPSTREAM_COMMIT=65389020769837e92e9fb939bac34bd9a3e25bb2

rm -rf "$WORK" && mkdir -p "$WORK" && cd "$WORK"
git clone https://github.com/acidanthera/BrcmPatchRAM.git src
cd src
git checkout "$UPSTREAM_COMMIT"
git apply "$HERE/mediatek.patch"
ln -s "$MKS" MacKernelSDK
cp -R "$LILU" Lilu.kext
xcodebuild -project BrcmPatchRAM.xcodeproj -scheme BlueToolFixup -configuration Release \
    CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" build
echo "Built: $(pwd)/build/Products/Release/BlueToolFixup.kext"
