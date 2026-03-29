# MAFP Fingerprint Driver (USB 3274:8012)

**[中文](README_zh.md)** | English

Practical build/install guide for the `MicroarrayTechnology MAFP` fingerprint device (`3274:8012`) on common Linux distributions.

This repository provides:
- driver source: `src/microarray.c`
- libfprint integration patch: `patches/0001-libfprint-add-microarray-3274-8012-driver.patch`
- full troubleshooting/dev manual: `docs/FINGERPRINT_MAFP_DEV_MANUAL.md`

---

## 1. Confirm Hardware

```bash
lsusb | grep 3274:8012
```

Expected: one line containing `3274:8012`.

---

## 2. Build Matrix

| Distro | Recommended flow |
|---|---|
| Fedora | Rebuild distro source package or local build from source tree |
| Debian / Ubuntu | `apt source libfprint` + patch + build |
| Arch Linux | Patch upstream source in `PKGBUILD` / local meson build |
| openSUSE | Patch source + meson build or OBS package |

---

## 3. Common Build Steps (all distros)

Inside a `libfprint` source tree (v1.94.x):

```bash
patch -p1 < /path/to/mafp-fingerprint-driver/patches/0001-libfprint-add-microarray-3274-8012-driver.patch

meson setup build-microarray -Ddoc=false -Dgtk-examples=false -Dintrospection=false
meson compile -C build-microarray
```

Output library:
- `build-microarray/libfprint/libfprint-2.so.2.0.0`

---

## 4. Fedora (tested)

### 4.1 Install build dependencies

```bash
sudo dnf install -y rpmdevtools meson ninja-build gcc git
sudo dnf builddep -y libfprint
```

### 4.2 Get source

Option A (RPM source workflow):

```bash
sudo dnf download --source libfprint
rpm -ivh libfprint-*.src.rpm
cd ~/rpmbuild/SOURCES
```

Option B (existing source tree):

```bash
cd /tmp/libfprint-src/libfprint-v1.94.10
```

### 4.3 Build

```bash
patch -p1 < /path/to/mafp-fingerprint-driver/patches/0001-libfprint-add-microarray-3274-8012-driver.patch
meson setup build-microarray -Ddoc=false -Dgtk-examples=false -Dintrospection=false
meson compile -C build-microarray
```

### 4.4 Install (local override)

```bash
sudo install -m 0755 build-microarray/libfprint/libfprint-2.so.2.0.0 /usr/lib64/libfprint-2.so.2.0.0
sudo ldconfig
sudo systemctl restart fprintd
```

### 4.5 Verify

```bash
fprintd-list $USER
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head
```

---

## 5. Debian / Ubuntu

### 5.1 Install build dependencies

```bash
sudo apt update
sudo apt install -y devscripts dpkg-dev meson ninja-build git
sudo apt build-dep -y libfprint
```

### 5.2 Get source

```bash
apt source libfprint
cd libfprint-*/
```

### 5.3 Build

```bash
patch -p1 < /path/to/mafp-fingerprint-driver/patches/0001-libfprint-add-microarray-3274-8012-driver.patch
meson setup build-microarray -Ddoc=false -Dgtk-examples=false -Dintrospection=false
meson compile -C build-microarray
```

### 5.4 Install (local override)

```bash
sudo install -m 0755 build-microarray/libfprint/libfprint-2.so.2.0.0 /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0
sudo ldconfig
sudo systemctl restart fprintd
```

### 5.5 Verify

```bash
fprintd-list $USER
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head
```

---

## 6. Arch Linux

### 6.1 Install dependencies

```bash
sudo pacman -S --needed base-devel meson ninja pkgconf git glib2 libgusb pixman openssl libusb systemd
```

### 6.2 Get source

```bash
git clone --depth=1 --branch v1.94.10 https://gitlab.freedesktop.org/libfprint/libfprint.git
cd libfprint
```

### 6.3 Build

```bash
patch -p1 < /path/to/mafp-fingerprint-driver/patches/0001-libfprint-add-microarray-3274-8012-driver.patch
meson setup build-microarray -Ddoc=false -Dgtk-examples=false -Dintrospection=false
meson compile -C build-microarray
```

### 6.4 Install (local override)

```bash
sudo install -m 0755 build-microarray/libfprint/libfprint-2.so.2.0.0 /usr/lib/libfprint-2.so.2.0.0
sudo ldconfig
sudo systemctl restart fprintd
```

### 6.5 Verify

```bash
fprintd-list $USER
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head
```

---

## 7. openSUSE

### 7.1 Install dependencies

```bash
sudo zypper install -y gcc meson ninja pkgconf-pkg-config git \
  glib2-devel libgusb-devel pixman-devel libopenssl-devel libusb-1_0-devel
```

### 7.2 Get source

```bash
git clone --depth=1 --branch v1.94.10 https://gitlab.freedesktop.org/libfprint/libfprint.git
cd libfprint
```

### 7.3 Build

```bash
patch -p1 < /path/to/mafp-fingerprint-driver/patches/0001-libfprint-add-microarray-3274-8012-driver.patch
meson setup build-microarray -Ddoc=false -Dgtk-examples=false -Dintrospection=false
meson compile -C build-microarray
```

### 7.4 Install (local override)

```bash
sudo install -m 0755 build-microarray/libfprint/libfprint-2.so.2.0.0 /usr/lib64/libfprint-2.so.2.0.0
sudo ldconfig
sudo systemctl restart fprintd
```

### 7.5 Verify

```bash
fprintd-list $USER
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head
```

---

## 8. Troubleshooting

### 8.1 `No driver found for USB device 3274:8012`

Check actual loaded library:

```bash
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head
```

If a backup file like `...libfprint-2.so.2.0.0.bak...` is loaded, remove backups from system library directory, then:

```bash
sudo ldconfig
sudo systemctl restart fprintd
```

### 8.2 `No devices available`

```bash
lsusb | grep 3274:8012
systemctl --no-pager --full status fprintd
journalctl -u fprintd -n 120 --no-pager
```

---

## 9. Project Layout

```
mafp-fingerprint-driver/
├── src/
│   └── microarray.c
├── patches/
│   └── 0001-libfprint-add-microarray-3274-8012-driver.patch
├── scripts/
│   └── build-fedora-local.sh
├── docs/
│   ├── FINGERPRINT_MAFP_DEV_MANUAL.md
│   └── upstream/
└── README.md
```

---

## 10. License

This project is released under the [MIT License](LICENSE).

