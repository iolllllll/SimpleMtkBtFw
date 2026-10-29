# MT7921 / MT7922 / MT7925 Bluetooth на macOS Sequoia и Tahoe — пошаговая установка

**Результат на тестовой машине:** Foxconn MT7925 (`0489:E14F`), macOS 26.7.1 Tahoe / Foxconn MT7921 (`0489:E0CD`), macOS 15.8.1 Sequoia, OpenCore, AMD →
Bluetooth включается, `Chipset: SRS_7922`, звук A2DP (AAC/SBC) работает, поиск и сопряжение устройств работают.
Технические детали: [MT7921-Sequoia.md](MT7921-Sequoia.md). Английская версия: [README](../README.md).

В `bluetoothd` macOS 15+ и 26+ есть собственный нативный MediaTek-драйвер (`USB SRS`), но он ограничен жёстким белым списком разрешённых чипов.
Эта схема даёт `SimpleMtkBtFw` загрузить прошивку в чип, пропатчить белый список `bluetoothd` на лету через `BlueToolFixup`, и подключить контроллер к системе.

---

## 0. Подходит ли ваша карта

```sh
ioreg -p IOUSB -l -w0 | grep -E '"(idVendor|idProduct|USB Product Name)"'
printf 'PID = 0x%04X\n' 57679      # пример: 57679 = 0xE14F (MT7925 Foxconn)
```

* Bluetooth-часть карты должна быть **USB-устройством** с **idVendor = 1161 (0x0489, Foxconn)** или **3725 (0x0E8D, MediaTek)**. Обычное имя: `Wireless_Device`.
* Поддерживаемые чипы: **MT7921 / MT7921K (AMD RZ608), MT7922 (AMD RZ616), MT7925 (Wi-Fi 7)**.
* USB-порт Bluetooth должен быть правильно сопоставлен в вашей USB-карте (USBToolBox/UTBMap, тип порта **Internal = 255**).
* Проверено с `amfi_get_out_of_my_way=0x1` и ослабленным SIP.

---

## 1. Конфигурация кекстов

В `EFI/OC/Kexts` и `config.plist → Kernel → Add`:

| № | BundlePath | Описание |
|---|---|---|
| 1 | `Lilu.kext` | Необходим для всех патчей (1.7.0+) |
| 2 | `SimpleMtkBtFw.kext` | Загрузчик прошивки MT7921/MT7922/MT7925 |
| 3 | `BlueToolFixup.kext` | Версия из папки `BlueToolFixup-MediaTek` с патчем белого списка Tahoe/Sequoia |

> **Внимание:** `SimpleMtkBtPatcher.kext` при использовании нативного транспорта `USB SRS` **не нужен** (отключите его).

---

## 2. NVRAM-переменные (критично!)

Добавьте переменные в `config.plist`:

* **`NVRAM → Add → 7C436110-AB2A-4BBB-A880-FE41995C9F82`**:
  * `bluetoothInternalControllerInfo` = `0000000000000000000000000000` (Data, **14** нулевых байт)
  * `bluetoothExternalDongleFailed` = `00` (Data, **1** нулевой байт)
* **`NVRAM → Delete → 7C436110-AB2A-4BBB-A880-FE41995C9F82`**:
  * Добавьте те же два ключа: `bluetoothInternalControllerInfo` и `bluetoothExternalDongleFailed`.

---

## 3. Прошивка в `/etc/bluetool`

`bluetoothd` на старте проверяет наличие файла прошивки в `/etc/bluetool`:

```sh
sudo mkdir -p /etc/bluetool
sudo cp BT_RAM_CODE_MT7922_1_1_hdr.bin /etc/bluetool/BT_RAM_CODE_MT7922_1_1_hdr.bin
sudo chown root:wheel /etc/bluetool/BT_RAM_CODE_MT7922_1_1_hdr.bin
sudo chmod 644 /etc/bluetool/BT_RAM_CODE_MT7922_1_1_hdr.bin
```

---

## 4. Boot-args (при необходимости)

* Если PID отличается от `0xE14F` (MT7925) и `0xE0CD` (MT7921): добавьте `smbtpid=0xXXXX` в строку `boot-args`.

---

## 5. Холодная загрузка

После применения настроек **полностью выключите компьютер**, отключите питание (тумблер на БП или розетка) на 10–15 секунд и включите снова.
*Чипы MediaTek на материнских платах AM4/AM5 питаются от дежурной линии +5VSB; обычная перезагрузка не сбрасывает зависший чип.*

---

## 6. Рекомендации по микрофону (HFP / SCO)

* В macOS на всех чипах сторонних производителей (MediaTek, Intel) профиль гарнитуры (HFP) работает через узкополосный кодек CVSD.
* При выборе микрофона Bluetooth-гарнитуры macOS принудительно переключает воспроизведение в режим телефонного звонка (8 кГц моно).
* **Рекомендация:** в *Системные настройки → Звук → Вход* выберите встроенный микрофон (AppleALC) или внешний микрофон, а Bluetooth-наушники оставьте только на *Выход*. В таком режиме наушники всегда играют в максимальном Hi-Fi A2DP стерео качестве.

---

## 7. Сборка из исходников одной командой

Если вы хотите собрать всё самостоятельно на macOS:

```sh
git clone --recurse-submodules https://github.com/iolllllll/SimpleMtkBtFw.git
cd SimpleMtkBtFw
./build.sh
```

Скрипт автоматически подготовит SDK, соберет `SimpleMtkBtFw.kext`, патченный `BlueToolFixup.kext` и сложит готовые файлы в папку `dist/`.

**Сборка и автоматическая установка на хакинтош:**
```sh
./build.sh --install
```
Скрипт скомпилирует проект, сам скопирует кексты в `EFI/OC/Kexts` на подключенном разделе EFI и установит прошивку в `/etc/bluetool`.
