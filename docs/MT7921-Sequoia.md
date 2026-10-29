# MediaTek MT7921 / MT7922 / MT7925 Bluetooth on macOS Sequoia and Tahoe (native `bluetoothd` path)

Status: **working** on:
- **Foxconn MT7925** (USB `0489:E14F`), macOS 26.7.1 (25G241) Tahoe, AMD B650 AM5 platform.
- **Foxconn MT7921** (USB `0489:E0CD`), macOS 15.8.1 (24H32) Sequoia, OpenCore, AMD platform.

Bluetooth powers on, controller reports `Chipset: SRS_7922`, valid MAC address, scanning and audio playback work.

## Why this is different from "just load the firmware"

macOS 15+ and 26+ `bluetoothd` ships its own MediaTek driver (a port of Linux `btmtk`: `MtkLoadRomPatch`,
`MtkPowerOn`, transport "USB SRS", chipset type 0xB, ROM patch from `/etc/bluetool`). It is
whitelisted only for specific USB devices (e.g. `Foxconn 0489:E0D8`). For unrecognized PIDs, `bluetoothd` falls back
to the Broadcom code path, which fails with MediaTek silicon (`Chipset: BCM_4350C2`, address `NULL`).

In macOS Tahoe 26.x, `bluetoothd` checks a 7-entry device table:
`0489:E0D8`, `0489:E0E0`, `0489:E0F1`, `0489:E0F2`, `0489:E0F6`, `0E8D:7922`, `13D3:3568`.

The patched `BlueToolFixup` dynamically modifies this whitelist in `cs_validate_page` memory hook to match your device PID (default `0xE14F` or `0xE0CD`, configurable via `smbtpid` boot-arg).

## What is needed

| # | Piece | Why |
|---|---|---|
| 1 | `BlueToolFixup.kext` from `BlueToolFixup-MediaTek/` (**replaces** stock BlueToolFixup) | stock fixes + whitelist patch for Sequoia / Tahoe inside `bluetoothd` |
| 2 | `SimpleMtkBtFw.kext` | loads the MT7921/MT7922/MT7925 ROM patch from embedded firmware |
| 3 | NVRAM `bluetoothInternalControllerInfo` = 14 zero bytes, `bluetoothExternalDongleFailed` = 1 zero byte | without them `bluetoothd` believes there is no internal controller and never probes USB dongles (`External Bluetooth dongle was not found`) |
| 4 | `/etc/bluetool/BT_RAM_CODE_MT7922_1_1_hdr.bin` | `bluetoothd` reads it; with the patch already loaded by SimpleMtkBtFw it logs `no need to load rom patch` |
| 5 | **Cold boot** (power off 10+ s) after every change | warm reboots leave the chip in a state where the first WMT command times out |

> Do **not** use `SimpleMtkBtPatcher.kext` for this native `USB SRS` setup (it hooks EP0/bulk for the generic third-party dongle driver).

## Expected log (`log show --last boot --predicate 'process == "bluetoothd"'`)

```
Found external Bluetooth dongle -- setting chipset to THIRD_PARTY_DONGLE
HCI Transport is set to USB SRS
[OI_HciIfc_Init_USB_SRS] -- Read Chip ID 0x00007961 (or 0x7925)
Found firmware: BT_RAM_CODE_MT7922_1_1_hdr.bin
mtkSendFwRomPatch: patch_status 2
mtkSendFwRomPatch: no need to load rom patch section0
MtkPowerOn: successful
Stack initialization complete
SRS_7922 supports the following VSCs
```

## NVMe APFS Boot Optimization (Samsung 970 EVO Plus / AMD AM5)

If boot time is unusually long (40–90 seconds delay on Apple logo):
Set `Kernel -> Quirks -> SetApfsTrimTimeout = 0` in OpenCore `config.plist`. This bypasses the lengthy `spaceman_trim_free_blocks` on non-Apple NVMe controllers at boot.
