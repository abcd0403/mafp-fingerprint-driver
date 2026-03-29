# MAFP Fingerprint Driver

中文 | **[English](README.md)**

适用于 **MicroarrayTechnology MAFP** 指纹读取器（USB `3274:8012`）的开源 Linux 驱动，通过 `libfprint` 和 `fprintd` 实现基于指纹的系统认证。

本驱动通过对 Windows 闭源驱动的逆向工程开发而成，是完全独立的开源实现 —— 不包含任何厂商二进制文件或专有代码。

## 功能

- **指纹录入** — 6 阶段按压/抬起采集流程
- **指纹验证** — 1:1 模板匹配
- **桌面登录** — 支持 GNOME/KDE PAM 认证及 `sudo`
- **模板存储** — 在设备闪存中存储最多 30 个指纹模板
- **手指检测** — 检测手指是否放置在传感器上

## 支持的硬件

| | |
|---|---|
| **USB ID** | `3274:8012` |
| **设备名称** | MicroarrayTechnology MAFP General Device |
| **外形** | USB-A nano 适配器 |

已测试设备：**TNP Nano USB 指纹读取器**（[Amazon B07DW62XS7](https://www.amazon.com/dp/B07DW62XS7)）

> **如何确认你的设备：**
> ```bash
> lsusb | grep 3274:8012
> ```

## 前置条件

- **操作系统：** Fedora 43（已测试；其他发行版参见 [开发手册](docs/FINGERPRINT_MAFP_DEV_MANUAL.md)）
- **libfprint** v1.94.x 源码
- **meson**、**gcc**、**glib2-devel**、**libusb-devel**
- **fprintd** 服务

## 快速开始

### 1. 构建

获取 libfprint 源码并应用补丁：

```bash
# 获取 libfprint 源码（Fedora）
rpmdevtools  # 确保 fedpkg 工具可用
./scripts/build-fedora-local.sh /path/to/libfprint-v1.94.10
```

或手动构建：

```bash
cd /path/to/libfprint-v1.94.10
patch -p1 < /path/to/mafp-fingerprint-driver/patches/0001-libfprint-add-microarray-3274-8012-driver.patch

meson setup build-microarray \
  -Ddoc=false -Dgtk-examples=false -Dintrospection=false
meson compile -C build-microarray
```

### 2. 安装

```bash
sudo install -m 0755 \
  build-microarray/libfprint/libfprint-2.so.2.0.0 \
  /usr/lib64/libfprint-2.so.2.0.0
sudo ldconfig
sudo systemctl restart fprintd
```

### 3. 验证

```bash
# 确认 fprintd 已识别设备
fprintd-list $USER

# 确认加载了正确的库
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head

# 检查 fprintd 服务状态
systemctl status fprintd
```

## 使用

### 录入指纹

```bash
# 录入默认手指（右手食指）
fprintd-enroll

# 录入指定手指
fprintd-enroll -f right-thumb-finger
```

系统会提示你按压并抬起手指 **6 次**。

### 验证指纹

```bash
fprintd-verify
```

### 配置 sudo / GDM 登录

录入完成后，指纹认证会自动用于以下场景：
- `sudo`（通过 PAM）
- GNOME 登录界面（GDM）
- `polkit` 认证弹窗

## 常见问题

### "No driver found for USB device 3274:8012"

动态链接器可能加载了旧的 `.bak` 备份文件。删除备份文件：

```bash
sudo rm -f /usr/lib64/libfprint-2.so.2.0.0.bak*
sudo ldconfig
sudo systemctl restart fprintd
```

### 设备未显示

```bash
# 确认 USB 层已检测到设备
lsusb | grep 3274:8012

# 检查 udev 规则
ls /lib/udev/rules.d/*fprint*
```

## 项目结构

```
mafp-fingerprint-driver/
├── src/
│   └── microarray.c              # 驱动源码（约 770 行）
├── patches/
│   └── 0001-libfprint-add-microarray-3274-8012-driver.patch
├── scripts/
│   └── build-fedora-local.sh     # Fedora 自动构建脚本
├── docs/
│   ├── FINGERPRINT_MAFP_DEV_MANUAL.md   # 完整开发手册
│   └── upstream/                         # 逆向工程笔记与参考资料
│       ├── CHANGELOG.upstream.md
│       ├── README.upstream.md
│       ├── fingerprint-driver-re.md
│       ├── fingerprint-reader-setup.md
│       └── reverse-engineering.md
├── LICENSE                         # MIT 许可证
└── README.md
```

## 跨发行版打包

参见 [`docs/FINGERPRINT_MAFP_DEV_MANUAL.md`](docs/FINGERPRINT_MAFP_DEV_MANUAL.md) 了解以下发行版的打包指南：

- **Debian / Ubuntu** — .deb 打包
- **Arch Linux** — AUR PKGBUILD
- **openSUSE** — OBS 构建服务

## 贡献到上游

向官方 `libfprint` 项目提交此驱动的步骤见[开发手册](docs/FINGERPRINT_MAFP_DEV_MANUAL.md)第 19 节。

## 许可证

本项目基于 [MIT 许可证](LICENSE) 发布。

## 致谢

本驱动通过对 `MicroarrayFingerprintDevice.dll` Windows 驱动（v9.47.11.214）的逆向工程实现，用于互操作性目的，适用相关法律（美国 DMCA §1201(f) / 欧盟《软件指令》第 6 条）。不包含任何厂商专有代码或二进制文件。
