# SimpleMtkBtFw

[![Build](https://github.com/flxxxxddd/SimpleMtkBtFw/actions/workflows/build.yml/badge.svg)](https://github.com/flxxxxddd/SimpleMtkBtFw/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/flxxxxddd/SimpleMtkBtFw)](https://github.com/flxxxxddd/SimpleMtkBtFw/releases)

[中文说明](README_CN.md) (upstream, not updated for this fork)

**Bluetooth for MediaTek MT7921 / MT7921K (AMD RZ608) / MT7922 / MT7925 on macOS Sequoia (15.x) and Tahoe (26.x).**

Two kexts:

- **`SimpleMtkBtFw.kext`** — loads the MediaTek firmware into the USB
  Bluetooth function of the card and enables the Bluetooth protocol. After
  that, macOS' own Bluetooth stack (`bluetoothd`) drives the controller.
- **`SimpleMtkBtPatcher.kext`** — a [Lilu](https://github.com/acidanthera/Lilu)
  plugin that fixes the places where MediaTek firmware and `bluetoothd`
  disagree (see [What changed in this fork](#what-changed-in-this-fork)).
  Without it on the generic dongle path, AirPods connect but play no sound.
  *(Note: Not needed when using the native `USB SRS` path on Sequoia/Tahoe).*

Wi-Fi for the same card: **[SimpleMtkWlan](https://github.com/flxxxxddd/SimpleMtkWlan)**.

> This fork makes Bluetooth actually usable on MT7921 / MT7922 / MT7925 / RZ608
> with macOS Sequoia and Tahoe: upstream loaded the firmware, but `bluetoothd`
> never brought the controller up (and later crashed), and AirPods stayed silent.

## Status

Tested configurations:
- **Foxconn MT7925** (Wi-Fi 7, USB `0489:E14F`), **macOS 26.7.1 Tahoe**, AMD B650 AM5 platform (`Chipset: SRS_7922`, native `USB SRS` path).
- **Foxconn MT7921** (USB `0489:E0CD`), **macOS 15.8.1 Sequoia**, OpenCore, AMD platform (`Chipset: SRS_7922`, native `USB SRS` path).
- **MT7921K** (RZ608, USB `0e8d:0608`), **macOS 15.8.1 Sequoia**, SMBIOS iMacPro1,1, Intel desktop (generic dongle path).

| Feature | State |
|---|---|
| Firmware load (cold boot), Bluetooth on/off | ✅ |
| Pairing, auto-reconnect | ✅ |
| A2DP audio playback (SBC/AAC) | ✅ |
| AirPods: audio (AAC-ELD), battery, controls, switching | ✅ |
| BLE scanning (nearby Apple devices, Find My) | ✅ |
| HFP microphone (CVSD, 8 kHz) | ⚠️ works, narrow-band 8 kHz (see [Microphone note](#troubleshooting)) |
| Wide-band speech (mSBC) | ❌ unsupported by macOS for non-Apple BT |
| Sleep / wake | ⚠️ untested |

Supported USB IDs: see [`SimpleMtkBtFw/Info.plist`](SimpleMtkBtFw/Info.plist)
(MT7921, MT7922, MT7922A, MT7925 and a generic MediaTek Bluetooth class match). The
firmware path accepts the internal chip IDs `0x7961` (MT7921), `0x7922`, and `0x7925`.

Embedded firmware: `BT_RAM_CODE_MT7961_1_2_hdr.bin`,
`BT_RAM_CODE_MT7961_1a_2_hdr.bin`, `BT_RAM_CODE_MT7922_1_1_hdr.bin`, `BT_RAM_CODE_MT7925_1_1_hdr.bin`.

## Installation (OpenCore)

### Option 1: Native MediaTek Driver (`USB SRS`) — Recommended for macOS 15 & 26

macOS 15+ and macOS 26+ have built-in support for MediaTek controllers (`USB SRS` transport, `Chipset: SRS_7922`), but restrict it using a vendor/PID whitelist in `bluetoothd`.

1. Kexts in `EFI/OC/Kexts` and `config.plist → Kernel → Add`:
   1. `Lilu.kext` (1.7.0+)
   2. `SimpleMtkBtFw.kext` (loads firmware into the card)
   3. `BlueToolFixup.kext` built from [`BlueToolFixup-MediaTek/`](BlueToolFixup-MediaTek/README.md) (dynamically patches the Tahoe / Sequoia whitelist to match your card PID).
   *(Do **not** use `SimpleMtkBtPatcher.kext` on this path).*
2. Add NVRAM variables (`NVRAM → Add` **and** `NVRAM → Delete`, GUID `7C436110-AB2A-4BBB-A880-FE41995C9F82`):
   - `bluetoothInternalControllerInfo` = `0000000000000000000000000000` (Data, 14 zero bytes)
   - `bluetoothExternalDongleFailed` = `00` (Data, 1 zero byte)
3. Copy firmware to `/etc/bluetool`:
   ```sh
   sudo mkdir -p /etc/bluetool
   sudo cp BT_RAM_CODE_MT7922_1_1_hdr.bin /etc/bluetool/BT_RAM_CODE_MT7922_1_1_hdr.bin
   sudo chown root:wheel /etc/bluetool/BT_RAM_CODE_MT7922_1_1_hdr.bin
   sudo chmod 644 /etc/bluetool/BT_RAM_CODE_MT7922_1_1_hdr.bin
   ```
4. Perform a **cold boot** (power off completely for 10–15 seconds).

### Option 2: Generic Third-Party Dongle Path

For older macOS versions or setups using the generic fallback driver:

1. Put into `EFI/OC/Kexts` and `config.plist → Kernel → Add`:
   1. `Lilu.kext`
   2. `BlueToolFixup.kext` (stock acidanthera build)
   3. `SimpleMtkBtFw.kext`
   4. `SimpleMtkBtPatcher.kext`
2. Add the same NVRAM variables as Option 1.
3. Reboot. `system_profiler SPBluetoothDataType` should show `Chipset: THIRD_PARTY_DONGLE` and `State: On`.

## Troubleshooting

* **Bluetooth device missing after a reboot** (nothing at the USB port, or
  `persistent enumeration failures` in the kernel log). The M.2 card keeps
  standby power (+5VSB) and its Bluetooth core can stay wedged. Shut down and cut
  power (PSU switch or unplug) for ~15–30 seconds.
* **Slow macOS boot on Samsung 970 EVO Plus / NVMe SSD.** If boot hangs for 40–90
  seconds on the Apple logo (waiting for `spaceman_trim_free_blocks`), set
  `Kernel → Quirks → SetApfsTrimTimeout` = `0` in OpenCore `config.plist`.
* **Music sounds like a phone call (HFP headset mode).** macOS switches Bluetooth
  headphones into mono 8 kHz CVSD headset mode whenever their microphone is selected as
  input. To keep high-fidelity A2DP stereo playback, select your motherboard / USB audio
  microphone for *Input* in System Settings → Sound.
* **Loader log.** Early-boot kernel logs are usually lost, so the loader keeps
  its own log and publishes it on the USB device:
  ```sh
  ioreg -l -w0 | grep -A20 MtkBtLog
  ```
* **Patcher counters.** `ioreg -l -w0 | grep -A1 '"SimpleMtkBtPatcher"'`
  shows how many HCI Read Clock commands and ACL packets were rewritten (Option 2 only).
* **`bluetoothd` keeps restarting / Bluetooth menu spins.** Check the NVRAM
  variables above. Crash reports in `/Library/Logs/DiagnosticReports` with
  `bcm_vsc.c` mean `bluetoothd` thinks the chip is Broadcom.
* **After many `bluetoothd` crashes launchd throttles it** (10–20 minutes).
  Restart it with `sudo launchctl kickstart -k system/com.apple.bluetoothd`.
* **HCI trace.** `bluetoothd` can write a PacketLogger trace:
  ```sh
  sudo defaults write /Library/Preferences/com.apple.MobileBluetooth.debug HCITraces -dict HCIFileTraces -bool true
  sudo pkill bluetoothd
  # trace: /private/var/root/Library/Logs/Bluetooth/bluetoothd-hci-latest.pklg
  sudo defaults delete /Library/Preferences/com.apple.MobileBluetooth.debug   # to disable
  ```

## Building

Requirements: macOS with Xcode.

```sh
git clone --recurse-submodules https://github.com/flxxxxddd/SimpleMtkBtFw.git
cd SimpleMtkBtFw
./scripts/bootstrap.sh          # MacKernelSDK submodule + Lilu SDK
for s in SimpleMtkBtFw SimpleMtkBtPatcher; do
  xcodebuild -project SimpleMtkBtFw.xcodeproj -scheme $s \
    -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
done
# -> build/Build/Products/Release/{SimpleMtkBtFw,SimpleMtkBtPatcher}.kext
```

`SimpleMtkBtFw/FwBinary.cpp` is regenerated from `SimpleMtkBtFw/fw/*.bin` by
`scripts/zlib_compress_fw.py` during the build.

CI builds Debug and Release on every push and pull request; pushing a tag
`vX.Y.Z` publishes a GitHub release.

## What changed in this fork

* **macOS 26 Tahoe & macOS 15 Sequoia native driver support (`USB SRS`).**
  Apple's native MediaTek driver is enabled by dynamically patching the `bluetoothd`
  device table via `BlueToolFixup-MediaTek`.
* **MT7925 Wi-Fi 7 chipset support.** Added `BT_RAM_CODE_MT7925_1_1_hdr.bin`,
  internal chip ID `0x7925`, and Foxconn PID `0xE14F`.
* **`bluetoothd` finds and accepts the controller.** On SMBIOS models with
  built-in Bluetooth, `bluetoothd` looked for Apple's internal module, did not
  find it and looped until its watchdog killed it. With the NVRAM variables above
  and the device's USB product name left untouched, it takes the third-party dongle path.
* **AirPods audio.** `bluetoothd` reads the BT clock with
  `HCI_Read_Clock(handle, Which_Clock = 0)` to timestamp AAC-ELD audio.
  MediaTek answers with Connection_Handle 0, so the result is never matched.
  The patcher hooks `IOUSBHostDevice::deviceRequest` and asks for the piconet clock
  (`Which_Clock = 1`).
* **ACL data as non-flushable.** The patcher rewrites the ACL packet
  boundary flag from "automatically flushable" to "non-flushable" on bulk OUT transfers.
* **The Intel LE random-address workaround** inherited from
  IntelBluetoothFirmware is opt-in now (`-smbtrandaddr`).
* **Debuggability.** A boot log ring buffer (`MtkBtLog` on the USB device),
  WMT patch status per firmware section, patcher counters on `IOResources`.

## Credits

* [laobamac (王孝慈)](https://github.com/laobamac) — SimpleMtkBtFw: MediaTek Bluetooth port, integration and testing
* [zxystd](https://github.com/zxystd) and [IntelBluetoothFirmware](https://github.com/OpenIntelWireless/IntelBluetoothFirmware) contributors — original framework and firmware tooling
* MediaTek Inc. — firmware; Linux `btmtk` / `btusb` authors — reference
* [acidanthera](https://github.com/acidanthera) — Lilu, MacKernelSDK, BlueToolFixup
* `dawalishi821` — network card hardware

## License

See the individual source file headers and the included license files. Files
adapted from upstream keep their original copyright and SPDX headers.
Firmware is redistributed under the MediaTek firmware license.

## Guides & Documentation

- **[Installation Guide in Russian / Руководство на русском](docs/INSTALL_RU.md)**: Полная пошаговая инструкция по установке, настройке OpenCore, NVRAM, USB-маппингу и рекомендациям по звуку.
- **[Native macOS 15 Sequoia & macOS 26 Tahoe MediaTek Driver (SRS Transport)](docs/MT7921-Sequoia.md)**: Подробный анализ нативного пути `bluetoothd`, структуры таблицы устройств Tahoe и патча `BlueToolFixup-MediaTek`.
- **[BlueToolFixup-MediaTek](BlueToolFixup-MediaTek/README.md)**: Патч для `bluetoothd` в macOS 15 & 26 (снятие хардкодного ограничения PID `0xE0D8` и патчинг 7-элементной таблицы Tahoe).
