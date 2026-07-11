# Windows / Linux Dual-boot UEFI Boot Entry Switcher

[Chinese Version | 中文说明](README.md)

This tool provides a set of scripts to **temporarily change the next boot entry** in a dual-boot environment with **Windows** and **Ubuntu (or other Linux)**. It allows one\E2\80\91click reboot into the desired system without manually pressing hotkeys or altering the BIOS boot order each time.

---

## \E2\9C\A8 Features

- **One\E2\80\91click switching** \E2\80\93 select the target system, automatically set the next boot order and reboot.
- **Automatic detection** \E2\80\93 Windows side scans UEFI firmware identifiers via `bcdedit`; Linux side parses `/boot/grub/grub.cfg` to list GRUB menu entries and auto\E2\80\91detects Windows entries.
- **Caching mechanism** \E2\80\93 Windows side caches identifiers to avoid repeated scans; Linux side parses in real time to keep the menu up\E2\80\91to\E2\80\91date.
- **Interactive & friendly** \E2\80\93 coloured output, timeout with default selection (Windows defaults to Ubuntu, Linux defaults to Windows), and cancellation support.
- **Cross\E2\80\91platform** \E2\80\93 includes both a **Windows batch** script and a **Linux shell** script to cover both systems.

---

## \F0\9F\93\A6 File Descriptions

| File name | System | Description |
|-----------|--------|-------------|
| `switch-boot_en.bat` | Windows (UEFI) | Windows switching script (uses `bcdedit`) |
| `switch-boot_en.sh` | Linux (Ubuntu) | Linux switching script (uses `grub-reboot`) |

> Both scripts can be used independently or deployed on their respective systems, allowing users to switch the boot entry from either OS.

---

## \F0\9F\96\A5\EF\B8\8F Windows Script Usage

### Requirements

- Windows 7 / 8 / 10 / 11 (64\E2\80\91bit, UEFI boot mode)
- Administrator privileges (the script checks and requires running as admin)
- `bcdedit` (built\E2\80\91in)

### Download & Preparation

1. Download `switch-boot_en.bat` to any local directory (recommend placing it outside the system drive to avoid accidental deletion).
2. If you encounter garbled Chinese characters, edit the file with a plain text editor (e.g. Notepad, Notepad++, VS Code) and save it with **ANSI** encoding before using.
3. Right\E2\80\91click the file and select **\E2\80\9CRun as administrator\E2\80\9D**.

### First Run

- The script automatically scans UEFI firmware boot entries to identify Windows Boot Manager and Ubuntu identifiers.
- If Ubuntu is not found, you will be prompted to manually enter its identifier (format like `{xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}`).
- After a successful scan, the identifiers are saved to a cache file `switch-boot.ini` in the same directory, so subsequent runs can read directly from cache.

### Menu Options

When run, the following menu is displayed:

    =============================================
               Boot Switcher Tool
    =============================================

      Current Configuration
        Windows ID: {bootmgr}
        Ubuntu  ID: {xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}
        Cache file: C:\path\to\switch-boot.ini

    =============================================
       Select System for Next Boot
    =============================================

      1 - Windows
      2 - Ubuntu (default, auto\E2\80\91select after 10s)
      3 - UEFI Firmware Settings
      r - Rescan and update cache
      q - Cancel

- After entering a number or letter, the script sets the UEFI `bootsequence` and reboots immediately (except for `q` which cancels).
- If no input is received within 10 seconds, **Ubuntu** is chosen by default.

### Manual Fallback (Preset)

If automatic detection consistently fails, you can manually set the Ubuntu identifier by editing the script and changing the following variable:

    set "MANUAL_UBUNTU_ID={your-ubuntu-identifier}"

The script will then use this preset and generate the cache file.

### Cache File Details

- File name: `switch-boot.ini` (located next to the `.bat` file)
- Example content:

    WIN_ID={bootmgr}
    UBUNTU_ID={xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}

- If the cache becomes corrupted or you need to rescan, choose option `r` from the menu, or simply delete the `.ini` file.

---

## \F0\9F\90\A7 Linux Script Usage

### Requirements

- Linux distribution with GRUB2 (e.g. Ubuntu, Debian, Fedora)
- Root privileges (the script checks and requires `sudo`)
- `grub-reboot` installed (usually provided by `grub-common` or `grub2-common`)
- `systemd` for the final reboot command

### Download & Deployment

1. Download `switch-boot_en.sh` to any directory.
2. Make it executable: `chmod +x switch-boot_en.sh`
3. (Optional) Move it to a `PATH` directory (e.g. `/usr/local/bin/`) and rename it to `switch-boot` for easier invocation:

    sudo cp switch-boot_en.sh /usr/local/bin/switch-boot
    sudo chmod 755 /usr/local/bin/switch-boot

### Usage

Run the script with `sudo` (required):

    sudo switch-boot

The script will:

1. Parse `/boot/grub/grub.cfg`, list all `menuentry` items with indices and names.
2. Automatically detect an entry containing `Windows` or `Boot Manager` as the default target; if not found, the first entry is used.
3. Prompt for user selection:
   - Press **Enter** to confirm the default.
   - Enter a **numeric index** to switch to another entry (supports multi\E2\80\91digit numbers, e.g. `12`).
   - Press **q** to cancel immediately (no reboot).
   - If **no input within 10 seconds**, the default entry is automatically chosen.
4. After confirmation, call `grub-reboot` to set the next boot entry, wait 3 seconds, then reboot via `systemctl reboot -i`.

### Example Run

    tom@localhost:~$ sudo switch-boot
    [sudo] password for tom:
    
    ====== GRUB Boot Menu Entries ======
       0 : Ubuntu
       1 : Windows Boot Manager (on /dev/nvme0n1p1)
    ====================================
    
    Default selected: [1] Windows Boot Manager (on /dev/nvme0n1p1)
    Waiting 10 seconds, will auto\E2\80\91reboot into the above if no action.
    Press Enter to confirm default, type index to switch, or q to cancel.

### Notes

- The script only changes the **next boot** entry; it does not alter the default GRUB order.
- Menu entry names with special characters are handled correctly via `awk`.
- Cancelling (by pressing `q`) exits immediately without setting any boot entry and without rebooting.
- The script depends on `grub-reboot`; if missing, install the appropriate package (e.g. `grub-common`).

---

## \E2\9A\A0\EF\B8\8F General Notes

- **UEFI mode** (Windows script) or **GRUB2** (Linux script) is required; legacy BIOS may not be fully supported.
- Must be run with **administrator/root** privileges; otherwise, boot configuration cannot be modified.
- The change only affects the **next** boot; after reboot, the default order is restored.
- If you use **GRUB** as the primary boot manager, the Linux script works directly; the Windows script is intended for scenarios where the system boots directly via UEFI firmware.
- If your antivirus (Windows) blocks the script, please add an exception \E2\80\93 it only uses system built\E2\80\91in commands and is not malicious.

---

## \F0\9F\9B\A0\EF\B8\8F FAQ

**Q (Windows): \E2\80\9CPlease run as administrator\E2\80\9D appears \E2\80\93 what to do?**  
A: Right\E2\80\91click the script file and select \E2\80\9CRun as administrator\E2\80\9D, or execute from an elevated Command Prompt.

**Q (Windows): Ubuntu identifier not found during scan?**  
A: Ensure Ubuntu is properly installed and appears in the UEFI boot list. You can check via UEFI firmware settings, or manually enter the identifier (you can find it using `bcdedit /enum firmware`).

**Q (Linux): \E2\80\9Cgrub-reboot failed\E2\80\9D \E2\80\93 what to do?**  
A: Verify that the target menu entry name is correct (case\E2\80\91sensitive). Test manually with `grub-reboot "entry name"`. If still failing, regenerate `grub.cfg` with `update-grub`.

**Q: After selection, the system does not reboot and shows an error?**  
A: Check that you are running with admin/root privileges, and that the required commands are available (Windows: `bcdedit`, Linux: `grub-reboot` and `systemctl`).

**Q: Can I delete the cache file (Windows)?**  
A: Yes \E2\80\93 deleting it forces a fresh scan on the next run.

---

## \F0\9F\93\9D Contributing & Feedback

Issues and Pull Requests are welcome!  
Repository: [GitHub xylz0928/UEFI-Switch-Boot](https://github.com/xylz0928/UEFI-Switch-Boot)

---

## \F0\9F\93\84 License

[MIT License](LICENSE)

---

> **Tip**: Both scripts are ready for use \E2\80\93 pick the one that matches your current operating system.
