# MAFP 指纹驱动 (USB 3274:8012)

中文 | **[English](README.md)**

在常见 Linux 发行版上构建/安装 `MicroarrayTechnology MAFP` 指纹设备 (`3274:8012`) 的实用指南。

本仓库提供：
- 驱动源码：`src/microarray.c`
- libfprint 集成补丁：`patches/0001-libfprint-add-microarray-3274-8012-driver.patch`
- 完整的故障排除/开发手册：`docs/FINGERPRINT_MAFP_DEV_MANUAL.md`

---

## 1. 确认硬件

```bash
lsusb | grep 3274:8012
```

预期输出：包含 `3274:8012` 的一行。

---

## 2. 构建矩阵

| 发行版 | 推荐流程 |
|---|---|
| Fedora | 重新构建发行版源码包，或从源码树本地构建 |
| Debian / Ubuntu | `apt source libfprint` + 打补丁 + 构建 |
| Arch Linux | 在 `PKGBUILD` 中为上游源码打补丁 / 本地 meson 构建 |
| openSUSE | 为源码打补丁 + meson 构建，或使用 OBS 包 |

---

## 3. 通用构建步骤（所有发行版）

在 `libfprint` 源码树（v1.94.x）内执行：

```bash
patch -p1 < /path/to/mafp-fingerprint-driver/patches/0001-libfprint-add-microarray-3274-8012-driver.patch

meson setup build-microarray -Ddoc=false -Dgtk-examples=false -Dintrospection=false
meson compile -C build-microarray
```

输出库文件：
- `build-microarray/libfprint/libfprint-2.so.2.0.0`

---

## 4. Fedora（已测试）

### 4.1 安装构建依赖

```bash
sudo dnf install -y rpmdevtools meson ninja-build gcc git
sudo dnf builddep -y libfprint
```

### 4.2 获取源码

方式 A（RPM 源码工作流）：

```bash
sudo dnf download --source libfprint
rpm -ivh libfprint-*.src.rpm
cd ~/rpmbuild/SOURCES
```

方式 B（已有源码树）：

```bash
cd /tmp/libfprint-src/libfprint-v1.94.10
```

### 4.3 构建

```bash
patch -p1 < /path/to/mafp-fingerprint-driver/patches/0001-libfprint-add-microarray-3274-8012-driver.patch
meson setup build-microarray -Ddoc=false -Dgtk-examples=false -Dintrospection=false
meson compile -C build-microarray
```

### 4.4 安装（本地覆盖）

```bash
sudo install -m 0755 build-microarray/libfprint/libfprint-2.so.2.0.0 /usr/lib64/libfprint-2.so.2.0.0
sudo ldconfig
sudo systemctl restart fprintd
```

### 4.5 验证

```bash
fprintd-list $USER
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head
```

---

## 5. Debian / Ubuntu

### 5.1 安装构建依赖

```bash
sudo apt update
sudo apt install -y devscripts dpkg-dev meson ninja-build git
sudo apt build-dep -y libfprint
```

### 5.2 获取源码

```bash
apt source libfprint
cd libfprint-*/
```

### 5.3 构建

```bash
patch -p1 < /path/to/mafp-fingerprint-driver/patches/0001-libfprint-add-microarray-3274-8012-driver.patch
meson setup build-microarray -Ddoc=false -Dgtk-examples=false -Dintrospection=false
meson compile -C build-microarray
```

### 5.4 安装（本地覆盖）

```bash
sudo install -m 0755 build-microarray/libfprint/libfprint-2.so.2.0.0 /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0
sudo ldconfig
sudo systemctl restart fprintd
```

### 5.5 验证

```bash
fprintd-list $USER
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head
```

---

## 6. Arch Linux

### 6.1 安装依赖

```bash
sudo pacman -S --needed base-devel meson ninja pkgconf git glib2 libgusb pixman openssl libusb systemd
```

### 6.2 获取源码

```bash
git clone --depth=1 --branch v1.94.10 https://gitlab.freedesktop.org/libfprint/libfprint.git
cd libfprint
```

### 6.3 构建

```bash
patch -p1 < /path/to/mafp-fingerprint-driver/patches/0001-libfprint-add-microarray-3274-8012-driver.patch
meson setup build-microarray -Ddoc=false -Dgtk-examples=false -Dintrospection=false
meson compile -C build-microarray
```

### 6.4 安装（本地覆盖）

```bash
sudo install -m 0755 build-microarray/libfprint/libfprint-2.so.2.0.0 /usr/lib/libfprint-2.so.2.0.0
sudo ldconfig
sudo systemctl restart fprintd
```

### 6.5 验证

```bash
fprintd-list $USER
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head
```

---

## 7. openSUSE

### 7.1 安装依赖

```bash
sudo zypper install -y gcc meson ninja pkgconf-pkg-config git \
  glib2-devel libgusb-devel pixman-devel libopenssl-devel libusb-1_0-devel
```

### 7.2 获取源码

```bash
git clone --depth=1 --branch v1.94.10 https://gitlab.freedesktop.org/libfprint/libfprint.git
cd libfprint
```

### 7.3 构建

```bash
patch -p1 < /path/to/mafp-fingerprint-driver/patches/0001-libfprint-add-microarray-3274-8012-driver.patch
meson setup build-microarray -Ddoc=false -Dgtk-examples=false -Dintrospection=false
meson compile -C build-microarray
```

### 7.4 安装（本地覆盖）

```bash
sudo install -m 0755 build-microarray/libfprint/libfprint-2.so.2.0.0 /usr/lib64/libfprint-2.so.2.0.0
sudo ldconfig
sudo systemctl restart fprintd
```

### 7.5 验证

```bash
fprintd-list $USER
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head
```

---

## 8. 故障排除

### 8.1 `No driver found for USB device 3274:8012`

检查实际加载的库文件：

```bash
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head
```

如果加载的是类似 `...libfprint-2.so.2.0.0.bak...` 的备份文件，请删除系统库目录中的备份文件，然后：

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

## 9. 项目结构

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

## 10. 许可证

本项目基于 [MIT 许可证](LICENSE) 发布。
