# Microarray 指纹驱动开发手册（可直接喂给 AI）

## 1. 目标与范围
本手册用于维护 `root@<TARGET_HOST>` 上的 USB 指纹设备（`3274:8012`，`MicroarrayTechnology MAFP General Device`）。

目标：
- 记录本次从“系统不识别/崩溃”到“恢复可用”的完整过程。
- 提供可复现、可回滚、可继续开发的步骤。
- 提供可直接贴给 AI 的上下文模板，避免 AI 误判为“配置小问题”。

---

## 2. 设备与系统基线
- 机器：`root@<TARGET_HOST>`
- 系统：Fedora 43
- 内核：`6.19.8-200.fc43.x86_64`
- 指纹设备：`USB VID:PID = 3274:8012`
- 关键组件：
  - `fprintd-1.94.5-2.fc43`
  - `libfprint-1.94.10-1.fc43`（但已被本地替换为自编译动态库）
  - GNOME + PAM + authselect

认证链路：
`GNOME / sudo / polkit -> PAM(pam_fprintd) -> fprintd -> libfprint driver -> USB device`

---

## 3. 原始故障现象（历史）
历史故障包含两类：
1. 识别错一次后，后续不继续识别。
2. GNOME 中指纹入口消失，`fprintd-list` 显示 `No devices available`。

日志中出现过：
- `No driver found for USB device 3274:8012`
- `SIGSEGV / SIGABRT / double free`（早期自定义驱动版本）
- `Deleted stored finger ... as it is unknown to device`

结论：
- 官方 Fedora `libfprint` 不包含这个硬件的可用驱动实现。
- 之前“能跑”的库是自定义版本；后来被包升级覆盖后失效。

---

## 4. 本次最终修复方案

### 4.1 驱动来源
使用第三方源码（已验证含 `3274:8012`）：
- 仓库：`jdillon/libfprint-microarray`
- 关键文件：`src/microarray.c`

### 4.2 融合到 Fedora 源码树
在 `libfprint-1.94.10` 源码中新增并启用 `microarray` 驱动：
- 新增文件：
  - `libfprint/drivers/microarray/microarray.c`
- 修改：
  - `meson.build`：`default_drivers` / `endian_independent_drivers` 增加 `microarray`
  - `libfprint/meson.build`：`driver_sources` 增加 `microarray -> drivers/microarray/microarray.c`

### 4.3 编译与部署
- 编译目录：`/tmp/libfprint-src/libfprint-v1.94.10/build-microarray`
- 产物：`libfprint/libfprint-2.so.2.0.0`
- 已部署到：`/usr/lib64/libfprint-2.so.2.0.0`
- 当前 build-id：
  - `<SANITIZED_BUILD_ID>`

### 4.4 修复中的关键坑
**坑：把备份库放在 `/usr/lib64` 会被动态链接器误加载**。

现象：
- `fprintd` 实际加载了 `/usr/lib64/libfprint-2.so.2.0.0.bak.*`
- 日志继续报 `No driver found for USB device 3274:8012`

处理：
- 将 `.bak` 文件移出 `/usr/lib64` 到 `/opt/libfprint-backup/`
- 执行 `ldconfig` 并重启 `fprintd`

---

## 5. 当前已验证状态
成功验证点：
- `fprintd-list <TARGET_USER>` 输出 `found 1 devices`
- 设备名显示 `MicroarrayTechnology MAFP`
- 能进入 enroll/verify 流程（不再是 `No devices available`）
- GNOME 指纹入口恢复（取决于当前会话刷新）

注：
- 当前 `/var/lib/fprint` 可为空，需要重新录入。

---

## 6. 关键文件与产物位置
- 驱动源码仓：`/opt/mafp-rebuild/libfprint-microarray-main`
- 本次补丁快照：`/opt/mafp-rebuild/libfprint-microarray-fedora.patch`
- 系统库备份：`/opt/libfprint-backup/libfprint-2.so.2.0.0.bak.<TIMESTAMP>`
- 融合后的源码树：`/tmp/libfprint-src/libfprint-v1.94.10`

---

## 7. 快速健康检查（建议每次改动后执行）
```bash
# 1) 设备可见性
fprintd-list <TARGET_USER>

# 2) 服务状态
systemctl --no-pager --full status fprintd

# 3) fprintd 实际加载的库（必须是非 .bak）
pid=$(pgrep -n fprintd)
grep libfprint /proc/$pid/maps | head

# 4) build-id 校验（用于确认是否为自编译库）
readelf -n /usr/lib64/libfprint-2.so.2.0.0 | sed -n '/Build ID/,+1p'

# 5) PAM 指纹开关状态
authselect current
sed -n '1,80p' /etc/pam.d/system-auth
```

---

## 8. 回滚方案
若新库有问题，可快速回退：
```bash
systemctl stop fprintd
cp -a /opt/libfprint-backup/libfprint-2.so.2.0.0.bak.<TIMESTAMP> /usr/lib64/libfprint-2.so.2.0.0
ldconfig
systemctl start fprintd
```

---

## 9. 再现/开发流程（从头重建）

```bash
# 0) 进入 root
sudo -i

# 1) 下载第三方驱动源码
mkdir -p /opt/mafp-rebuild
cd /opt/mafp-rebuild
curl -fsSL -o libfprint-microarray-main.tar.gz \
  https://codeload.github.com/jdillon/libfprint-microarray/tar.gz/refs/heads/main
tar -xzf libfprint-microarray-main.tar.gz

# 2) 准备 Fedora libfprint 源码（这里假设已在 /tmp/libfprint-src/...）
LP=/tmp/libfprint-src/libfprint-v1.94.10
mkdir -p "$LP/libfprint/drivers/microarray"
cp /opt/mafp-rebuild/libfprint-microarray-main/src/microarray.c \
   "$LP/libfprint/drivers/microarray/microarray.c"

# 3) 按“本手册第 4.2 节”修改 meson.build 两处文件
#    (default_drivers/endian_independent_drivers/driver_sources)

# 4) 编译
cd "$LP"
rm -rf build-microarray
meson setup build-microarray -Ddoc=false -Dgtk-examples=false -Dintrospection=false
meson compile -C build-microarray

# 5) 部署
install -m 0755 build-microarray/libfprint/libfprint-2.so.2.0.0 /usr/lib64/libfprint-2.so.2.0.0
# 警告：不要把 .bak 留在 /usr/lib64
ldconfig
systemctl restart fprintd
```

---

## 10. 已知风险与后续改进方向
1. 驱动是逆向实现，不是上游官方合并版本，后续内核/USB 时序变化可能带来回归。
2. 目前依赖用户态轮询与状态机，错误指纹后的恢复逻辑仍需持续压测。
3. 建议后续工作：
   - 把本地改动制作成规范 patch（尽量提交到 fork 并版本化）。
   - 增加自动化 smoke test（enroll + verify + wrong finger + retry）。
   - 引入 crash 采集脚本，减少现场排障时间。

---

## 11. 故障时一键采集信息（给 AI）
在故障发生后执行：

```bash
ssh root@<TARGET_HOST> '
set -e
printf "=== BASE ===\n"
date
uname -a
rpm -q libfprint fprintd || true

printf "\n=== DEVICE ===\n"
lsusb -d 3274:8012 || true

printf "\n=== SERVICE ===\n"
systemctl --no-pager --full status fprintd | sed -n "1,120p"

printf "\n=== LOADED LIB ===\n"
pid=$(pgrep -n fprintd || true)
if [ -n "$pid" ]; then
  grep libfprint /proc/$pid/maps | head -n 10
fi
readelf -n /usr/lib64/libfprint-2.so.2.0.0 | sed -n "/Build ID/,+1p"

printf "\n=== FPRINTD LOG (recent) ===\n"
journalctl -u fprintd -n 200 --no-pager

printf "\n=== ENROLLMENT DATA ===\n"
find /var/lib/fprint -maxdepth 5 -print 2>/dev/null || true

printf "\n=== PAM/AUTHSELECT ===\n"
authselect current || true
sed -n "1,120p" /etc/pam.d/system-auth
sed -n "1,120p" /etc/pam.d/fingerprint-auth
'
```

---

## 12. 直接喂给 AI 的提示词模板（可复制）
把下面模板连同本手册一起给 AI：

```text
你现在是 Fedora 指纹驱动排障工程师。请严格基于我提供的《FINGERPRINT_MAFP_DEV_MANUAL.md》执行。

环境：
- 主机：root@<TARGET_HOST>
- 设备：USB 3274:8012 (MicroarrayTechnology MAFP)
- 当前问题：<在这里写现象，例如“错一次后无法继续识别”>
- 期望结果：GNOME 锁屏、sudo、polkit 均可稳定使用指纹

约束：
1) 不要先给泛泛建议，先验证“fprintd实际加载的libfprint路径与build-id”。
2) 必须先判断是“驱动未加载/加载错库/状态机问题/PAM问题”哪一类。
3) 每次修改后都要给出可执行验证命令和预期输出。
4) 如果要替换库，备份文件不能留在 /usr/lib64（避免再次被误加载）。
5) 最终输出：根因、改动、验证结果、回滚命令。

请先执行你认为最关键的前三个检查命令，并解释为什么。
```

---

## 13. 维护建议（团队协作）
- 任何改库动作都记录：`日期 + build-id + 变更摘要 + 回滚文件名`。
- 每次升级 Fedora 后先做第 7 节健康检查。
- 出现 bug 时优先保留现场，不要先重装/重录，先采集第 11 节数据。


---

## 14. 常见发行版打包策略（统一思路）

核心原则：
- 不做“另起库名”的并存包（`fprintd` 直接依赖 `libfprint-2.so.2`）。
- 做“基于发行版原包的补丁重打包”，版本后缀区分（如 `+mafp1`、`.mafp1`）。
- 保持 ABI 与包名兼容，降低桌面/PAM 侧改动。

统一补丁来源：
- `libfprint/drivers/microarray/microarray.c`
- `meson.build`（driver list）
- `libfprint/meson.build`（driver_sources）
- 建议补丁文件名：`0001-libfprint-add-microarray-3274-8012-driver.patch`

---

## 15. Fedora 打包（RPM / COPR）

推荐流程：
```bash
# 1) 拿 Fedora 源包
sudo dnf download --source libfprint
rpm -ivh libfprint-*.src.rpm
cd ~/rpmbuild/SPECS

# 2) 放补丁到 SOURCES，并在 spec 中加入 Patch/Release 后缀
#    例如 Release: 1%{?dist}.mafp1

# 3) 构建
rpmbuild -ba libfprint.spec

# 4) 安装验证
sudo dnf install ~/rpmbuild/RPMS/x86_64/libfprint-*.rpm
sudo systemctl restart fprintd
fprintd-list <TARGET_USER>
```

发布建议：
- 个人/团队分发：用 COPR 托管仓库。
- 命名建议：`libfprint` 原名不变，仅 `Release` 带 `mafp` 后缀。

---

## 16. Debian / Ubuntu 打包（.deb / PPA）

Debian 本地包：
```bash
sudo apt build-dep libfprint
apt source libfprint
cd libfprint-*/

# 应用补丁并更新 changelog
# dch -i   # 版本建议加 +mafp1

dpkg-buildpackage -us -uc -b
```

Ubuntu PPA：
```bash
# 先构建 source package，再上传到 Launchpad PPA
# dput <ppa-target> ../*.changes
```

版本建议：
- Debian: `1.94.10-1+mafp1`
- Ubuntu: `1.94.10-1ubuntuX+mafp1`

---

## 17. Arch Linux 打包（PKGBUILD / AUR）

建议：
- 做 `libfprint-microarray` 包。
- `provides=('libfprint')`
- `conflicts=('libfprint')`
- 在 `prepare()` 应用补丁，在 `build()` 用 meson/ninja。

最小骨架示例：
```bash
pkgname=libfprint-microarray
pkgver=1.94.10
pkgrel=1
arch=('x86_64')
url='https://fprint.freedesktop.org/'
license=('LGPL2.1')
depends=('glib2' 'gusb' 'pixman' 'openssl')
provides=('libfprint')
conflicts=('libfprint')
source=("https://gitlab.freedesktop.org/libfprint/libfprint/-/archive/v$pkgver/libfprint-v$pkgver.tar.gz"
        '0001-libfprint-add-microarray-3274-8012-driver.patch')
sha256sums=('SKIP' 'SKIP')

prepare() {
  cd "libfprint-v$pkgver"
  patch -p1 -i "$srcdir/0001-libfprint-add-microarray-3274-8012-driver.patch"
}

build() {
  cd "libfprint-v$pkgver"
  meson setup build -Ddoc=false -Dgtk-examples=false -Dintrospection=false
  meson compile -C build
}

package() {
  cd "libfprint-v$pkgver"
  DESTDIR="$pkgdir" meson install -C build
}
```

---

## 18. openSUSE 打包（OBS）

推荐流程：
```bash
# 1) 在 OBS 上 branch libfprint 包
# 2) 上传补丁并在 spec 中加 Patch
# 3) osc build 本地验证
# 4) 提交到你的 OBS 项目仓库
```

要点：
- 仍采用“原包补丁重打包”模式。
- Release 建议加 `mafp` 后缀便于运维识别。

---

## 19. 贡献到主线（upstream）操作指南

这里的“主线”指：`libfprint` 上游仓库（freedesktop GitLab）。

### 19.1 先做的准备
1. 把当前驱动改动整理为干净 commit（不要混入本地临时调试代码）。
2. 准备协议说明文档（命令、响应、状态码、端点）。
3. 准备可复现场景：enroll、verify、wrong finger、连续重试。
4. 明确法律边界：仅提交自主实现代码，不带厂商闭源二进制。

### 19.2 上游通常关心的点
1. 代码风格与 GLib/libfprint 内部 API 规范。
2. 驱动行为是否稳定（尤其错误路径恢复）。
3. 是否有测试/录包（至少能让维护者复现核心流程）。
4. 文档是否说明设备特性与限制。

### 19.3 你要发什么
1. Issue（可先发 Driver Request / 设计说明）。
2. Merge Request（MR）分小步提交：
   - 提交1：构建系统接入（meson）
   - 提交2：驱动主体
   - 提交3：测试/文档
3. MR 描述中附：硬件型号、USB ID、日志片段、已知限制。

### 19.4 容易被拒的原因
1. 带闭源 shim 或依赖专有 blob。
2. 错误路径不完整，出现死循环/崩溃。
3. 未说明协议来源与可验证性。
4. 改动过大但缺少拆分与测试证据。

---

## 20. 给 AI 的“打包+上游贡献”模板

```text
你是 Linux 指纹驱动发布工程师。请基于《FINGERPRINT_MAFP_DEV_MANUAL.md》执行。

目标：
1) 产出 Fedora / Debian(含Ubuntu) / Arch / openSUSE 四套可构建包方案。
2) 给出“上游 libfprint 提交 MR”的最小可接受改动集。

约束：
- 不能建议并存两个不同 libfprint 运行库名；必须兼容 fprintd 现有依赖。
- 必须输出每个发行版的：版本命名规则、构建命令、回滚命令、验证命令。
- 必须识别并规避“/usr/lib64 下 .bak 被误加载”的坑。
- 输出按“可直接执行命令 + 预期结果”格式。

先给我一份发布矩阵表（发行版、包格式、构建工具、仓库发布方式、风险点），再展开每一项。
```

