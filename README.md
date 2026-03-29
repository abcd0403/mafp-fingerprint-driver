# MAFP Fingerprint Driver

**[中文](README_zh.md)** | English

An open-source Linux driver for **MicroarrayTechnology MAFP** fingerprint readers (USB `3274:8012`), enabling fingerprint-based authentication on Linux desktops via `libfprint` and `fprintd`.

This driver was developed by reverse-engineering the proprietary Windows driver and implements a fully open-source replacement — no vendor binaries or proprietary code are included.

## Features

- **Fingerprint enrollment** — 6-stage press/lift capture cycle
- **Fingerprint verification** — 1:1 template matching
- **Desktop login** — Works with GNOME/KDE PAM authentication and `sudo`
- **Template storage** — Stores up to 30 fingerprint templates on device flash
- **Finger-present detection** — Detects when a finger is placed on the sensor

## Supported Hardware

| | |
|---|---|
| **USB ID** | `3274:8012` |
| **Device Name** | MicroarrayTechnology MAFP General Device |
| **Form Factor** | USB-A nano dongle |

Tested with: **TNP Nano USB Fingerprint Reader** ([Amazon B07DW62XS7](https://www.amazon.com/dp/B07DW62XS7))

> **How to check your device:**
> ```bash
> lsusb | grep 3274:8012
> ```

## Prerequisites

- **OS:** Fedora 43 (tested; see [docs](docs/FINGERPRINT_MAFP_DEV_MANUAL.md) for Debian/Ubuntu, Arch, openSUSE notes)
- **libfprint** v1.94.x source tree
- **meson**, **gcc**, **glib2-devel**, **libusb-devel`
- **fprintd** service

## Quick Start

### 1. Build

Clone the libfprint source and apply the included patch:

```bash
# Get libfprint source (Fedora)
rpmdevtools  # ensures you have fedpkg tools
./scripts/build-fedora-local.sh /path/to/libfprint-v1.94.10
```

Or build manually:

```bash
cd /path/to/libfprint-v1.94.10
patch -p1 < /path/to/mafp-fingerprint-driver/patches/0001-libfprint-add-microarray-3274-8012-driver.patch

meson setup build-microarray \
  -Ddoc=false -Dgtk-examples=false -Dintrospection=false
meson compile -C build-microarray
```

### 2. Install

```bash
sudo install -m 0755 \
  build-microarray/libfprint/libfprint-2.so.2.0.0 \
  /usr/lib64/libfprint-2.so.2.0.0
sudo ldconfig
sudo systemctl restart fprintd
```

### 3. Verify

```bash
# Check that fprintd sees your device
fprintd-list $USER

# Verify the correct library is loaded
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head

# Check fprintd service status
systemctl status fprintd
```

## Usage

### Enroll a fingerprint

```bash
# Enroll with default finger (right index)
fprintd-enroll

# Enroll a specific finger
fprintd-enroll -f right-thumb-finger
```

You'll be prompted to press and lift your finger **6 times**.

### Verify

```bash
fprintd-verify
```

### Configure for sudo / GDM

Once enrolled, fingerprint authentication is automatically available for:
- `sudo` (via PAM)
- GNOME login screen (GDM)
- `polkit` authentication dialogs

## Troubleshooting

### "No driver found for USB device 3274:8012"

The dynamic linker may be loading an old `.bak` file instead of the new library. Remove any backup files:

```bash
sudo rm -f /usr/lib64/libfprint-2.so.2.0.0.bak*
sudo ldconfig
sudo systemctl restart fprintd
```

### Device not showing up

```bash
# Verify the device is detected at USB level
lsusb | grep 3274:8012

# Check udev rules
ls /lib/udev/rules.d/*fprint*
```

## Project Structure

```
mafp-fingerprint-driver/
├── src/
│   └── microarray.c              # Driver source (~770 lines)
├── patches/
│   └── 0001-libfprint-add-microarray-3274-8012-driver.patch
├── scripts/
│   └── build-fedora-local.sh     # Automated build script for Fedora
├── docs/
│   ├── FINGERPRINT_MAFP_DEV_MANUAL.md   # Full development manual
│   └── upstream/                         # Reverse engineering notes & references
│       ├── CHANGELOG.upstream.md
│       ├── README.upstream.md
│       ├── fingerprint-driver-re.md
│       ├── fingerprint-reader-setup.md
│       └── reverse-engineering.md
├── LICENSE                         # MIT License
└── README.md
```

## Cross-Distro Packaging

See [`docs/FINGERPRINT_MAFP_DEV_MANUAL.md`](docs/FINGERPRINT_MAFP_DEV_MANUAL.md) for packaging guides:

- **Debian / Ubuntu** — .deb packaging
- **Arch Linux** — AUR PKGBUILD
- **openSUSE** — OBS build service

## Upstream Contribution

Steps for submitting this driver to the official `libfprint` project are documented in section 19 of the [development manual](docs/FINGERPRINT_MAFP_DEV_MANUAL.md).

## License

This project is released under the [MIT License](LICENSE).

## Acknowledgments

This driver was reverse-engineered from the `MicroarrayFingerprintDevice.dll` Windows driver (v9.47.11.214) for interoperability purposes under applicable law (DMCA §1201(f) / EU Software Directive Art. 6). No proprietary vendor code or binaries are included.
