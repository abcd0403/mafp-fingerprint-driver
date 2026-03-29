# MAFP 指纹驱动 (USB 3274:8012)

中文 | **[English](README.md)**

一款面向 **MicroarrayTechnology MAFP** 指纹读取器（USB `3274:8012`）的开源 libfprint 驱动，通过 `fprintd` 和 PAM 在 Linux 上实现指纹录入与验证。

该驱动通过对 Windows WBDI 驱动（`MicroarrayFingerprintDevice.dll` v9.47.11.214）的逆向工程开发而成，使用 Ghidra 12.0.4 进行分析。这是一个完全独立的开源实现——不包含任何厂商二进制文件或专有代码。

## 功能

- **指纹录入** — 6 阶段按压/抬起采集流程
- **指纹验证** — 1:1 模板匹配（对比设备闪存中的 FID 槽位）
- **桌面登录** — 支持 GNOME / KDE PAM 认证及 `sudo`
- **设备端存储** — 在设备闪存中存储最多 30 个指纹模板
- **手指检测** — 在录入过程中轮询传感器检测手指是否放置

## 支持的硬件

| | |
|---|---|
| **USB ID** | `3274:8012` |
| **设备名称** | MicroarrayTechnology MAFP General Device |
| **外形** | USB-A nano 适配器 |

已测试设备：**TNP Nano USB 指纹读取器**（[Amazon B07DW62XS7](https://www.amazon.com/dp/B07DW62XS7)）

> **确认你的设备：**
> ```bash
> lsusb | grep 3274:8012
> ```

## 工作原理

本项目通过向上游 [libfprint](https://gitlab.freedesktop.org/libfprint/libfprint)（v1.94.x）源码树添加 microarray 驱动补丁，然后编译安装生成的 `libfprint-2.so` 库。修改后的库是发行版原包的直接替换。

**认证链路：**
```
GNOME / sudo / polkit  ->  PAM (pam_fprintd)  ->  fprintd  ->  libfprint  ->  USB 设备
```

---

## 快速开始

### 1. 安装构建依赖

<details>
<summary>Fedora</summary>

```bash
sudo dnf install -y rpmdevtools meson ninja-build gcc git cpio
sudo dnf builddep -y libfprint
```
</details>

<details>
<summary>Debian / Ubuntu</summary>

```bash
sudo apt update
sudo apt install -y devscripts dpkg-dev meson ninja-build git
sudo apt build-dep -y libfprint
```

> **注意：** 如果 `apt build-dep` 因版本冲突失败，可能需要启用 `deb-src` 源。在 Ubuntu 上，编辑 `/etc/apt/sources.list.d/ubuntu.sources`，确保 `Types` 行包含 `deb-src`。
</details>

### 2. 获取 libfprint 源码

<details>
<summary>Fedora（RPM 源码包）</summary>

```bash
sudo dnf download --source libfprint
rpm -ivh libfprint-*.src.rpm

mkdir -p /tmp/libfprint-src
cd /tmp/libfprint-src
rpm2cpio ~/rpmbuild/SRPMS/libfprint-*.src.rpm | cpio -idmv

tar -xf libfprint-v*.tar.gz
cd libfprint-v*/
```
</details>

<details>
<summary>Debian / Ubuntu</summary>

```bash
apt source libfprint
cd libfprint-*/
```
</details>

### 3. 打补丁并编译

```bash
patch -p1 < /path/to/mafp-fingerprint-driver/patches/0001-libfprint-add-microarray-3274-8012-driver.patch

meson setup build-microarray -Ddoc=false -Dgtk-examples=false -Dintrospection=false
meson compile -C build-microarray
```

产物：`build-microarray/libfprint/libfprint-2.so.2.0.0`

### 4. 安装并验证

#### Fedora

```bash
# 备份原库
sudo cp /usr/lib64/libfprint-2.so.2.0.0 /usr/lib64/libfprint-2.so.2.0.0.orig

# 安装新编译的库
sudo install -m 0755 build-microarray/libfprint/libfprint-2.so.2.0.0 /usr/lib64/libfprint-2.so.2.0.0

# 重要：将备份移出系统库目录！
sudo mkdir -p /opt/libfprint-backup
sudo mv /usr/lib64/libfprint-2.so.2.0.0.orig /opt/libfprint-backup/

sudo ldconfig
sudo systemctl restart fprintd

# 验证
fprintd-list $USER
```

#### Debian / Ubuntu

```bash
sudo cp /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0 /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0.orig
sudo install -m 0755 build-microarray/libfprint/libfprint-2.so.2.0.0 /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0
sudo mkdir -p /opt/libfprint-backup
sudo mv /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0.orig /opt/libfprint-backup/
sudo ldconfig
sudo systemctl restart fprintd
fprintd-list $USER
```

预期输出：
```
found 1 devices
Device at /net/reactivated/Fprint/Device/0
Using device /net/reactivated/Fprint/Device/0
User <用户名> has no fingers enrolled for MicroarrayTechnology MAFP.
```

### 5. 录入指纹

```bash
fprintd-enroll $USER
# 在传感器上放置手指 6 次
```

### 6. 测试验证

```bash
fprintd-verify $USER
# 放置已录入的手指
```

---

## 库文件安装路径

| 发行版 | 库路径 |
|---|---|
| Fedora | `/usr/lib64/libfprint-2.so.2.0.0` |
| Debian / Ubuntu | `/usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0` |

---

## 使用脚本自动化（Fedora）

提供了 Fedora 的一键构建脚本：

```bash
./scripts/build-fedora-local.sh /path/to/libfprint-source
```

---

## 故障排除

### `No driver found for USB device 3274:8012`

最常见的原因是 `fprintd` 加载了旧的备份库而非你新编译的版本。

```bash
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head
```

如果看到加载了 `.bak` 或 `.orig` 文件，将它们移出系统库目录：

#### Fedora

```bash
sudo mv /usr/lib64/libfprint-2.so.2.0.0.bak /opt/libfprint-backup/
sudo ldconfig
sudo systemctl restart fprintd
```

#### Debian / Ubuntu

```bash
sudo mv /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0.bak /opt/libfprint-backup/
sudo ldconfig
sudo systemctl restart fprintd
```

### `No devices available`

```bash
# 确认设备已连接
lsusb | grep 3274:8012

# 检查服务状态
systemctl --no-pager --full status fprintd

# 查看日志
journalctl -u fprintd -n 120 --no-pager
```

### 补丁无法应用

所附补丁基于 libfprint **v1.94.10** 生成。如果你的发行版使用了不同版本，请手动应用修改：

1. **`meson.build`** — 在 `default_drivers` 和 `endian_independent_drivers` 列表中添加 `'microarray'`
2. **`libfprint/meson.build`** — 添加驱动源码映射：
   ```meson
   'microarray' :
       [ 'drivers/microarray/microarray.c' ],
   ```
3. **`libfprint/drivers/microarray/microarray.c`** — 从本仓库的 `src/microarray.c` 复制

### 每次修改后的健康检查

#### Fedora

```bash
# 设备可见性
fprintd-list $USER

# 服务状态
systemctl --no-pager --full status fprintd

# 实际加载的库（必须不是 .bak）
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head

# Build-id
readelf -n /usr/lib64/libfprint-2.so.2.0.0 | sed -n '/Build ID/,+1p'
```

#### Debian / Ubuntu

```bash
fprintd-list $USER
systemctl --no-pager --full status fprintd
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head
readelf -n /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0 | sed -n '/Build ID/,+1p'
```

---

## 项目结构

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
│       ├── CHANGELOG.upstream.md
│       ├── README.upstream.md
│       ├── fingerprint-driver-re.md
│       ├── fingerprint-reader-setup.md
│       └── reverse-engineering.md
├── LICENSE
└── README.md
```

## 许可证

本项目基于 [MIT 许可证](LICENSE) 发布。
