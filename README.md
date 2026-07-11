# Windows / Linux 双系统 UEFI 启动项切换工具

[English Version | 英文说明](README_en.md)

本工具提供一组脚本，用于在 **Windows** 与 **Ubuntu（或其他 Linux）** 双系统环境下，**单次修改下次启动项**，实现一键重启进入指定系统，无需每次手动按热键或修改 BIOS 顺序。

---

## ✨ 特性

- **一键切换**：选择目标系统，自动设置下次启动顺序并重启。
- **自动识别**：Windows 端通过 `bcdedit` 扫描 UEFI 固件标识符；Linux 端通过解析 `/boot/grub/grub.cfg` 获取 GRUB 菜单项，并自动检测 Windows 项。
- **缓存机制**：Windows 端支持缓存标识符，避免重复扫描；Linux 端每次实时解析，保证菜单始终最新。
- **交互友好**：彩色输出，超时默认选项（Windows 端默认 Ubuntu，Linux 端默认 Windows），支持取消操作。
- **跨平台支持**：本项目包含 **Windows 批处理** 和 **Linux Shell** 两套实现，满足不同系统的操作需求。

---

## 📦 文件说明

| 文件名 | 适用系统 | 说明 |
|--------|----------|------|
| `switch-boot.bat` | Windows（UEFI） | Windows 端切换脚本（使用 `bcdedit`） |
| `switch-boot.sh` | Linux（Ubuntu） | Linux 端切换脚本（使用 `grub-reboot`） |

> 两份脚本可独立使用，也可分别部署在各自系统中，方便双系统用户从任意环境切换启动项。

---

## 🖥️ Windows 脚本使用说明

### 环境要求

- Windows 7 / 8 / 10 / 11（64 位，UEFI 启动模式）
- 管理员权限（脚本会自动检测并以管理员身份运行）
- 已安装 `bcdedit`（系统自带）

### 下载与准备

1. 将 `switch-boot.bat` 下载到本地任意目录（推荐放在非系统盘，避免误删）。
2. 如遇中文乱码，请使用`Windows 文本文档`, `NotePad++`, 或`VS Code`等等工具，编辑，转为`ANSI`格式保存为`bat`文件。
3. 右键点击该文件，选择 **“以管理员身份运行”**。

### 首次运行

- 脚本会自动扫描 UEFI 固件中的启动项，识别 Windows Boot Manager 和 Ubuntu 的标识符。
- 如果未找到 Ubuntu，会提示您手动输入标识符（格式如 `{xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}`）。
- 扫描成功后，脚本会将标识符保存到同目录下的 `switch-boot.ini` 缓存文件中，下次运行可直接读取。

### 菜单选项

运行后显示如下菜单：
```cmd
=============================================
           启动切换工具
=============================================

  当前配置
    Windows ID: {bootmgr}
    Ubuntu  ID: {xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}
    缓存文件: C:\path\to\switch-boot.ini

=============================================
   选择下次启动系统
=============================================

  1 - Windows
  2 - Ubuntu（默认，10秒后自动）
  3 - UEFI 固件设置
  r - 重新扫描并更新缓存
  q - 取消
```
- 输入对应数字或字母后，脚本将设置 UEFI 的 `bootsequence` 并立即重启（除 `q` 取消外）。
- 若 10 秒无操作，默认选择 **Ubuntu**。

### 手动预设（备选方案）

若自动扫描始终无法获取 Ubuntu 标识符，可直接编辑脚本，修改以下变量：

    set "MANUAL_UBUNTU_ID={你的Ubuntu标识符}"

脚本会优先使用该预设值，并生成缓存文件。

### 缓存文件说明

- 文件名：`switch-boot.ini`（与 `.bat` 同目录）
- 内容示例：
```txt
    WIN_ID={bootmgr}
    UBUNTU_ID={xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}
```
- 若缓存损坏或需重新扫描，可在菜单中选择 `r` 删除缓存并重新扫描，或直接删除 `.ini` 文件。

---

## 🐧 Linux 脚本使用说明

### 环境要求

- Linux 发行版（基于 GRUB2 引导，如 Ubuntu、Debian、Fedora 等）
- root 权限（脚本内部会检查，需使用 `sudo` 运行）
- 已安装 `grub-reboot`（通常由 `grub-common` 或 `grub2-common` 包提供）
- 系统使用 `systemd`（用于最终重启命令）

### 下载与部署

1. 将 `switch-boot.sh` 下载到任意目录。
2. 赋予执行权限：`chmod +x switch-boot.sh`
3. 建议移动到 `PATH` 目录（如 `/usr/local/bin/`）并重命名为 `switch-boot`，以便直接调用：
```bash
    sudo cp switch-boot.sh /usr/local/bin/switch-boot
    sudo chmod 755 /usr/local/bin/switch-boot
```
### 使用方法

运行脚本（必须使用 `sudo`）：

    sudo switch-boot

脚本将执行以下操作：

1. 解析 `/boot/grub/grub.cfg`，列出所有 `menuentry` 项，显示序号和名称。
2. 自动检测包含 `Windows` 或 `Boot Manager` 的项作为默认目标（若未找到，则默认选择第一项）。
3. 提示用户进行选择：
   - 直接按 **Enter** 键确认默认项。
   - 输入 **数字序号** 切换到其他项（支持多位数，如 `12`）。
   - 按 **q** 键立即取消操作，不重启。
   - 若 **10 秒无任何输入**，自动选择默认项。
4. 确认选择后，调用 `grub-reboot` 设置下次启动项，然后等待 3 秒后通过 `systemctl reboot -i` 重启系统。

### 运行示例
```bash
    tom@localhost:~$ sudo switch-boot 
    [sudo: authenticate] 密码：         
    
    ====== GRUB 启动菜单项 ======
       0 : Ubuntu
       1 : Windows Boot Manager (on /dev/nvme0n1p1)
    ===============================
    
    默认选中：[1] Windows Boot Manager (on /dev/nvme0n1p1)
    等待 10 秒，若无操作将自动重启进入上述系统。
    按 Enter 确认默认，输入 序号 切换到其他项，按 q 立即取消
```

### 注意事项

- 脚本仅修改 **下次启动** 项，不会改动 GRUB 的默认顺序。
- 若菜单项名称中含有特殊字符，脚本已通过 `awk` 正确处理，无需担心。
- 取消操作（按 `q`）会直接退出，不会设置任何启动项，也不会重启。
- 脚本依赖 `grub-reboot` 命令，若系统中不存在，请安装相应软件包（如 `grub-common`）。

---

## ⚠️ 通用注意事项

- **仅适用于 UEFI 模式**（Windows 脚本）或 GRUB2 引导（Linux 脚本），传统 BIOS 可能不支持。
- 必须以 **管理员/root** 权限运行，否则无法修改启动配置。
- 修改启动项仅影响 **下一次** 启动，重启后恢复为默认顺序。
- 若双系统使用 **GRUB** 作为主引导，Linux 脚本可直接操作；Windows 脚本适用于直接通过 UEFI 原生引导的场景。
- 如遇杀毒软件拦截（Windows），请放行或添加信任（脚本仅调用系统自带命令，无恶意行为）。

---

## 🛠️ 常见问题

**Q（Windows）: 运行后提示“请以管理员身份运行”怎么办？**  
A: 右键脚本文件 → “以管理员身份运行”，或在命令提示符（管理员）中执行。

**Q（Windows）: 扫描不到 Ubuntu 标识符怎么办？**  
A: 确保 Ubuntu 已正确安装并存在于 UEFI 启动列表中。可在 UEFI 固件设置中查看，或手动输入标识符（可通过 `bcdedit /enum firmware` 查找）。

**Q（Linux）: 提示“grub-reboot 执行失败”怎么办？**  
A: 检查目标菜单项名称是否准确（注意大小写），或尝试直接运行 `grub-reboot "菜单项名称"` 测试。若仍失败，可能是 GRUB 配置问题，可重新生成 `grub.cfg`（`update-grub`）。

**Q: 选择后没有重启，而是报错？**  
A: 检查是否以管理员/root 权限运行，或确认相关命令可用（Windows 的 `bcdedit`、Linux 的 `grub-reboot` 和 `systemctl`）。

**Q: 缓存文件可以删除吗（Windows）？**  
A: 可以，删除后下次运行会重新扫描。

---

## 📝 贡献与反馈

欢迎提交 Issue 或 Pull Request 改进脚本。  
项目地址：[GitHub xylz0928/UEFI-Switch-Boot](https://github.com/xylz0928/UEFI-Switch-Boot)

---

## 📄 许可证

[MIT License](LICENSE)

---

> **提示**：两套脚本均已就绪，您可以根据所在系统选择对应版本使用。
