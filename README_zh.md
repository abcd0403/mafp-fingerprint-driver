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
GNOME / sudo / polkit  →  PAM (pam_fprintd)  →  fprintd  →  libfprint  →  USB 设备
```

---

## 快速开始

### 1. 安装构建依赖

<details>
<summary>Fedora</summary>

```bash
sudo dnf install -y rpmdevtools meson ninja-build gcc git
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

> **注意：** 如果 `apt build-dep` 因版本冲突失败，可能需要启用 `deb-src` 源。在 Ubuntu 上，编辑 `/etc/apt/sources.list.d/ubuntu.sources`，确保 `Types` 行包含 `deb-src`。如果基础库版本不同步（例如 `libpcre2-8-0` 已安装版本高于可用的 `-dev` 包），先用 `sudo apt install --allow-downgrades <包名>=<版本>` 降级。
</details>

<details>
<summary>Arch Linux</summary>

```bash
sudo pacman -S --needed base-devel meson ninja pkgconf git \
  glib2 libgusb pixman openssl libusb systemd
```
</details>

<details>
<summary>openSUSE</summary>

```bash
sudo zypper install -y gcc meson ninja pkgconf-pkg-config git \
  glib2-devel libgusb-devel pixman-devel libopenssl-devel libusb-1_0-devel
```
</details>

### 2. 获取 libfprint 源码

<details>
<summary>Fedora（RPM 源码包）</summary>

```bash
sudo dnf download --source libfprint
rpm -ivh libfprint-*.src.rpm
cd ~/rpmbuild/SOURCES
```
</details>

<details>
<summary>Debian / Ubuntu</summary>

```bash
apt source libfprint
cd libfprint-*/
```
</details>

<details>
<summary>Arch / openSUSE（上游 git）</summary>

```bash
git clone --depth=1 --branch v1.94.10 \
  https://gitlab.freedesktop.org/libfprint/libfprint.git
cd libfprint
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

```bash
# 备份原库，然后安装（根据你的发行版调整库路径）
sudo cp /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0 /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0.orig
sudo install -m 0755 build-microarray/libfprint/libfprint-2.so.2.0.0 /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0

# 警告：将备份移出系统库目录！
sudo mv /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0.orig /opt/libfprint-backup/

sudo ldconfig
sudo systemctl restart fprintd

# 验证
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
| Arch Linux | `/usr/lib/libfprint-2.so.2.0.0` |
| openSUSE | `/usr/lib64/libfprint-2.so.2.0.0` |

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
# 检查 fprintd 实际加载了哪个库
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head
```

如果看到加载了 `.bak` 或 `.orig` 文件，将它们移出系统库目录：

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

所附补丁基于 libfprint **v1.94.10** 生成。如果你的发行版使用了不同版本（如 `1.94.7+tod1`），请手动应用修改：

1. **`meson.build`** — 在 `default_drivers` 和 `spi_drivers` 列表中添加 `'microarray'`
2. **`libfprint/meson.build`** — 添加驱动源码映射：
   ```meson
   'microarray' :
       [ 'drivers/microarray/microarray.c' ],
   ```
3. **`libfprint/drivers/microarray/microarray.c`** — 从本仓库的 `src/microarray.c` 复制

### 每次修改后的健康检查

```bash
# 设备可见性
fprintd-list $USER

# 服务状态
systemctl --no-pager --full status fprintd

# 实际加载的库（必须不是 .bak）
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head

# 验证 build-id 是否匹配你编译的库
readelf -n /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0 | sed -n '/Build ID/,+1p'
```

### 回滚

```bash
sudo systemctl stop fprintd
sudo cp -a /opt/libfprint-backup/libfprint-2.so.2.0.0.orig /usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0
sudo ldconfig
sudo systemctl start fprintd
```

---

## 项目结构

```
mafp-fingerprint-driver/
├── src/
│   └── microarray.c              # 驱动源码（libfprint 集成）
├── patches/
│   └── 0001-libfprint-add-microarray-3274-8012-driver.patch
├── scripts/
│   └── build-fedora-local.sh     # Fedora 自动化构建脚本
├── docs/
│   ├── FINGERPRINT_MAFP_DEV_MANUAL.md   # 开发运维手册
│   └── upstream/
│       ├── fingerprint-driver-re.md     # 协议逆向工程笔记
│       ├── README.upstream.md
│       └── CHANGELOG.upstream.md
├── LICENSE
├── README.md
└── README_zh.md
```

---

## 已知限制

- **模板溢出时全量擦除**：当 30 个 FID 槽位全部占满时，录入新手指会擦除所有已存储模板（CMD 0x0D）
- **未使用中断端点**：驱动使用轮询方式而非中断端点（EP 0x82）检测手指
- **不支持 1:N 搜索**：仅实现了针对特定 FID 槽位的 1:1 验证
- **非上游版本**：这是第三方补丁；发行版包更新会覆盖你自定义的库

---

## 发行版打包

为了更持久地安装，建议构建正式包而非直接替换库文件：

| 发行版 | 格式 | 备注 |
|---|---|---|
| Fedora | RPM / COPR | `Release: 1%{?dist}.mafp1` |
| Debian / Ubuntu | .deb / PPA | `1.94.10-1+mafp1` |
| Arch Linux | PKGBUILD / AUR | `provides=('libfprint')`，`conflicts=('libfprint')` |
| openSUSE | OBS | 分支包，在 spec 中添加补丁 |

详细的打包说明请参见 [`docs/FINGERPRINT_MAFP_DEV_MANUAL.md`](docs/FINGERPRINT_MAFP_DEV_MANUAL.md)。

---

## 贡献到上游

该驱动有潜力提交到 [libfprint 上游仓库](https://gitlab.freedesktop.org/libfprint/libfprint)。关键要求：

- 干净的提交历史，拆分为：构建系统修改、驱动实现、测试
- 稳定的错误路径恢复（错误手指时不会死循环或崩溃）
- 协议文档（命令、响应、状态码）
- 不包含厂商二进制文件或专有 shim

---

## 参考资料

- [libfprint 源码](https://gitlab.freedesktop.org/libfprint/libfprint)
- [libfprint 驱动编写指南](https://fprint.freedesktop.org/libfprint-dev/writing-a-driver.html)
- [FPC/GROW 指纹传感器协议](https://www.waveshare.com/wiki/UART_Fingerprint_Sensor_(C))

---

## 许可证

本项目基于 [MIT 许可证](LICENSE) 发布。
