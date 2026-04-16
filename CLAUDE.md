# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **铜豌豆 Linux (AtzLinux)** project - a Debian-based Linux distribution for Chinese desktop users. It provides:

- Customized Debian ISO builds with pre-configured Chinese localization
- APT repository with ~90 curated Chinese applications
- One-click install scripts for popular Chinese software
- Preseed files for automated, unattended Debian installation

## Repository Structure

### Key Directories

- `isodvd/` - ISO build configurations using simple-cdd
  - `profiles/` - Build profiles (.conf, .packages, .preseed files)
  - Versioned subdirectories (e.g., `12.13/`) contain package lists for each release
  - Build scripts: `amd64.build.sh`, `hwy-amd64*.build.sh`, `txy*.build.sh`

- `apt-mirror/` - APT repository synchronization configuration
  - `mirror.list` - Third-party APT sources to mirror
  - `pkg-download-url.list` - Direct download URLs for packages without APT repos
  - `Atzlinux-DEB-Package-Check-Rules-0.2.md` - Package quality standards

- `etc/apt/` - Repository configurations
  - `sources.list.d/` - Third-party source definitions
  - `trusted.gpg.d/` - GPG keys for third-party repositories

- Individual package directories (contain `download.url.txt` and uninstall scripts):
  - `wps/`, `wechat/`, `linuxqq/`, `baidunetdisk/`, `netease-cloud-music/`
  - `sogoupinyin/`, `youdao-dict/`, `wine-qq/`, `flashplayer/`, `stardict/`

- `debian-cn-keyring/` - Repository keyring management scripts
- `tools/` - Logo generation and utility scripts
- `project-doc/` - Project documentation and server info
- `changelog/` - Release changelogs

## Build Commands

### Build ISO Images

All ISO builds use `simple-cdd` and require root privileges.

```bash
# Standard amd64 build (bookworm)
cd isodvd
sudo ./amd64.build.sh

# Build specific profiles
sudo ./hwy-amd64-xfce.build.sh    # Huawei Cloud mirror, XFCE desktop
sudo ./hwy-amd64-xall.build.sh    # Huawei Cloud mirror, all desktops
sudo ./txy-amd64-xfce.build.sh    # Tencent Cloud mirror, XFCE desktop
sudo ./hwy-amd64-kde.build.sh     # KDE desktop variant
sudo ./hwy-i386.build.sh          # 32-bit build
```

Build output goes to `/tmp/simple-cdd/` by default.

### Build Configuration Files

- `profiles/amd64.build.conf` - Main build configuration
  - Sets `debian_mirror_extra` to local AtzLinux repo
  - Defines `backports_packages` for firmware and kernel
  - Sets version info (`DEBVERSION`, `CDNAME`, `VOLID_BASE`)

- `profiles/atzlinux-amd64-*.packages` - Package lists for each variant
- `profiles/atzlinux-amd64-xall.preseed` - Preseed file (zh_CN locale, auto-partitioning)

## Common Tasks

### Adding a New Package to ISO

1. Add package name to appropriate `profiles/atzlinux-amd64-*.packages` file
2. If package comes from backports, add to `backports_packages` in `amd64.build.conf`
3. Run `profiles/check-package-uniq.sh` to check for duplicates

### Adding Third-Party Software

For software with APT repository:
1. Add source to `apt-mirror/mirror.list`
2. Add GPG key to `etc/apt/trusted.gpg.d/`
3. Add source list to `etc/apt/sources.list.d/`

For direct download:
1. Add URL to `apt-mirror/pkg-download-url.list`

### Update Package Lists for Release

Versioned package lists are stored in `isodvd/<version>/atzlinux-<version>-amd64-DVD-1.list`:

```bash
# After building ISO, copy package list to version directory
cp /tmp/simple-cdd/atzlinux-12.13.1-amd64-DVD-1.list isodvd/12.13/
```

### Install Scripts

Main install script orchestrates individual component installers:
- `install.sh` - Install all Chinese applications
- `install-debian-cn-repo.sh` - Add AtzLinux APT repository
- `install-debian-cn-keyring.sh` - Install repository GPG key
- Individual install scripts: `install-wps.sh`, `install-wechat.sh`, etc.

### Repository Management

```bash
# Add repository key and source
./install-debian-cn-keyring.sh
./debian-cn-keyring/add-debian-cn-repo.sh

# Clear repository configuration
./debian-cn-keyring/clear-debian-cn-repo.sh
```

## Important Conventions

- **Locale**: All ISO builds default to `zh_CN.UTF-8` with US keyboard layout
- **Passwords**: Preseed files contain default passwords (visible in `atzlinux-amd64-xall.preseed`)
- **Firmware**: `FORCE_FIRMWARE=1` ensures non-free firmware on disc 1
- **Package Quality**: All packages must pass lintian checks and install/uninstall tests per `Atzlinux-DEB-Package-Check-Rules-0.2.md`

## Dependencies for Building

Required packages for ISO builds:
- `simple-cdd` - Debian CD build tool
- `apt-mirror` - For repository synchronization
- `debian-cd` - Debian CD creation tools
- `debian-archive-keyring`, `atzlinux-archive-keyring` - Keyrings

## Related Resources

- Website: https://www.atzlinux.com/
- Package list: https://www.atzlinux.com/allpackages.htm
- Gitee mirror: https://gitee.com/atzlinux/debian-cn

## LiveCD Build Commands

The liveCD provides a demo/try-before-install experience with the same XFCE desktop and Chinese localization as the installed version.

### Build LiveCD

```bash
cd isodvd/livecd
sudo ./build-livecd.sh [--mirror huawei|tencent|debian]
```

**Mirror options**:
- `huawei` (default) - Huawei Cloud mirrors
- `tencent` - Tencent Cloud mirrors
- `debian` - Official Debian mirrors

**Output**: `/tmp/livecd/atzlinux-live-<version>-amd64.iso`

**Testing**:
```bash
# Test in QEMU
qemu-system-x86_64 -m 2048 -cdrom /tmp/livecd/atzlinux-live-*.iso

# Write to USB (replace /dev/sdX with your USB device)
sudo dd if=/tmp/livecd/atzlinux-live-*.iso of=/dev/sdX bs=4M status=progress
```

### LiveCD Features

- Boots directly to XFCE desktop (auto-login as `live` user)
- Chinese locale (zh_CN.UTF-8) pre-configured
- Sogou pinyin input method ready to use
- Same package set as XFCE installer profile
- No persistence (pure live session, changes lost on reboot)

### LiveCD Directory Structure

- `isodvd/livecd/build-livecd.sh` - Main build script
- `isodvd/livecd/hooks/chroot/` - Chroot customization hooks
  - `01-setup-locale.chroot` - Configure Chinese locale
  - `02-configure-input-methods.chroot` - Setup fcitx + sogoupinyin
  - `03-customize-desktop.chroot` - Desktop branding and settings
- `isodvd/livecd/hooks/binary/` - Binary assembly hooks
  - `01-copy-gpg-keys.binary` - GPG key setup

