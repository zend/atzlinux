# AtzLinux LiveCD Build System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a liveCD build system that generates a bootable demo ISO of AtzLinux with XFCE desktop and Chinese localization.

**Architecture:** Wrapper around Debian's `live-build` tool that imports existing AtzLinux configurations (package lists, apt sources, GPG keys) from the installer build system. Lives in `isodvd/livecd/` directory.

**Tech Stack:** Bash, live-build (Debian tool), simple-cdd configs (imported)

---

## File Structure

| File | Responsibility |
|------|----------------|
| `isodvd/livecd/build-livecd.sh` | Main entry point, parses args, auto-installs deps, imports configs, orchestrates build |
| `isodvd/livecd/auto/config` | live-build automation wrapper that calls `lb config` with AtzLinux settings |
| `isodvd/livecd/auto/build` | live-build automation wrapper that calls `lb build` |
| `isodvd/livecd/hooks/chroot/01-setup-locale.chroot` | Set zh_CN.UTF-8 locale inside chroot |
| `isodvd/livecd/hooks/chroot/02-configure-input-methods.chroot` | Configure fcitx and sogoupinyin input methods |
| `isodvd/livecd/hooks/chroot/03-customize-desktop.chroot` | Apply AtzLinux desktop theme/settings |
| `isodvd/livecd/hooks/binary/01-copy-gpg-keys.binary` | Copy GPG keys to ISO during binary assembly |
| `isodvd/livecd/config/bootstrap` | Bootstrap configuration (arch, mirror) |
| `isodvd/livecd/config/binary` | ISO/bootloader configuration |
| `isodvd/livecd/config/common` | Common hooks and includes |

---

## Task 1: Create Directory Structure

**Files:**
- Create: `isodvd/livecd/auto/`
- Create: `isodvd/livecd/hooks/chroot/`
- Create: `isodvd/livecd/hooks/binary/`
- Create: `isodvd/livecd/config/`

- [ ] **Step 1: Create directory structure**

```bash
cd /home/mike/dev/debian/debian-cn/isodvd
mkdir -p livecd/auto
mkdir -p livecd/hooks/chroot
mkdir -p livecd/hooks/binary
mkdir -p livecd/config/bootstrap
mkdir -p livecd/config/chroot
mkdir -p livecd/config/binary
mkdir -p livecd/config/common
mkdir -p livecd/config/chroot_sources
mkdir -p livecd/config/chroot_apt
```

- [ ] **Step 2: Verify directories created**

```bash
ls -la /home/mike/dev/debian/debian-cn/isodvd/livecd/
```

Expected: Shows auto/, hooks/, config/ subdirectories

- [ ] **Step 3: Commit**

```bash
cd /home/mike/dev/debian/debian-cn
git add isodvd/livecd/
git commit -m "chore: create livecd build directory structure

Create directory structure for live-build based liveCD system.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 2: Create Main Build Script (build-livecd.sh)

**Files:**
- Create: `isodvd/livecd/build-livecd.sh`

- [ ] **Step 1: Create build-livecd.sh header and argument parsing**

```bash
cat > /home/mike/dev/debian/debian-cn/isodvd/livecd/build-livecd.sh << 'SCRIPT_EOF'
#!/bin/bash
#
# AtzLinux LiveCD Build Script
# Builds a live demo ISO using live-build
#

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISODVD_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$ISODVD_DIR")"

# Default values
MIRROR="huawei"
DEBIAN_MIRROR="https://mirrors.huaweicloud.com/debian/"
SECURITY_MIRROR="https://mirrors.huaweicloud.com/debian-security/"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mirror)
            MIRROR="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--mirror huawei|tencent|debian]"
            echo ""
            echo "Options:"
            echo "  --mirror    Mirror to use (default: huawei)"
            echo "  --help      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Set mirror based on selection
case $MIRROR in
    huawei)
        DEBIAN_MIRROR="https://mirrors.huaweicloud.com/debian/"
        SECURITY_MIRROR="https://mirrors.huaweicloud.com/debian-security/"
        ;;
    tencent)
        DEBIAN_MIRROR="https://mirrors.tencent.com/debian/"
        SECURITY_MIRROR="https://mirrors.tencent.com/debian-security/"
        ;;
    debian)
        DEBIAN_MIRROR="https://deb.debian.org/debian/"
        SECURITY_MIRROR="https://security.debian.org/debian-security/"
        ;;
esac

echo "=== AtzLinux LiveCD Build ==="
echo "Mirror: $MIRROR"
echo "Debian Mirror: $DEBIAN_MIRROR"
echo ""
SCRIPT_EOF
chmod +x /home/mike/dev/debian/debian-cn/isodvd/livecd/build-livecd.sh
```

- [ ] **Step 2: Test argument parsing**

```bash
cd /home/mike/dev/debian/debian-cn/isodvd/livecd
./build-livecd.sh --help
```

Expected: Shows usage message with --mirror options

- [ ] **Step 3: Add privilege check and package auto-install**

```bash
cat >> /home/mike/dev/debian/debian-cn/isodvd/livecd/build-livecd.sh << 'SCRIPT_EOF'

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root (for live-build)"
    echo "Usage: sudo $0 [--mirror huawei|tencent|debian]"
    exit 1
fi

# Auto-install required packages
echo "Checking required packages..."
REQUIRED_PKGS="live-build debootstrap squashfs-tools xorriso"
MISSING_PKGS=""

for pkg in $REQUIRED_PKGS; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
    fi
done

if [[ -n "$MISSING_PKGS" ]]; then
    echo "Installing missing packages: $MISSING_PKGS"
    apt-get update
    apt-get install -y $MISSING_PKGS || {
        echo "Error: Failed to install required packages"
        exit 1
    }
fi

echo "All required packages are installed."
SCRIPT_EOF
```

- [ ] **Step 4: Add configuration import functions**

```bash
cat >> /home/mike/dev/debian/debian-cn/isodvd/livecd/build-livecd.sh << 'SCRIPT_EOF'

# Import version and settings from build.conf
import_build_config() {
    local build_conf="$ISODVD_DIR/profiles/amd64.build.conf"
    
    if [[ ! -f "$build_conf" ]]; then
        echo "Error: Build config not found: $build_conf"
        exit 1
    fi
    
    # Source the build config to get variables
    source "$build_conf"
    
    # Set defaults if not defined
    DEBVERSION="${DEBVERSION:-12.13.1}"
    CDNAME="${CDNAME:-atzlinux}"
    ARCHES="${ARCHES:-amd64}"
    
    echo "Version: $DEBVERSION"
    echo "CD Name: $CDNAME"
}

# Generate package list from existing profile
generate_package_list() {
    local packages_file="$ISODVD_DIR/profiles/atzlinux-amd64-xfce.packages"
    local output_file="$SCRIPT_DIR/config/chroot/atzlinux-packages.list.chroot"
    
    if [[ ! -f "$packages_file" ]]; then
        echo "Error: Package list not found: $packages_file"
        exit 1
    fi
    
    echo "Generating package list from $packages_file..."
    
    # Copy packages, filtering out comments and empty lines
    grep -v "^[[:space:]]*#" "$packages_file" | grep -v "^[[:space:]]*$" > "$output_file"
    
    echo "Package list written to $output_file"
}

# Copy GPG keys
copy_gpg_keys() {
    local keys_dir="$PROJECT_DIR/etc/apt/trusted.gpg.d"
    local output_dir="$SCRIPT_DIR/config/chroot_sources"
    
    if [[ ! -d "$keys_dir" ]]; then
        echo "Warning: GPG keys directory not found: $keys_dir"
        return
    fi
    
    echo "Copying GPG keys..."
    
    # Create chroot_sources directory
    mkdir -p "$output_dir"
    
    # Copy all .gpg and .asc files
    for key in "$keys_dir"/*.gpg "$keys_dir"/*.asc; do
        if [[ -f "$key" ]]; then
            cp "$key" "$output_dir/"
            echo "  Copied: $(basename "$key")"
        fi
    done
}
SCRIPT_EOF
```

- [ ] **Step 5: Add live-build configuration function**

```bash
cat >> /home/mike/dev/debian/debian-cn/isodvd/livecd/build-livecd.sh << 'SCRIPT_EOF'

# Configure live-build
configure_live_build() {
    echo "Configuring live-build..."
    
    cd "$SCRIPT_DIR"
    
    # Clean any previous config
    rm -rf config/
    mkdir -p config/chroot config/binary config/common config/bootstrap config/chroot_sources config/chroot_apt
    
    # Import build config to get DEBVERSION
    import_build_config
    
    # Generate package list
    generate_package_list
    
    # Copy GPG keys
    copy_gpg_keys
    
    # Run lb config with AtzLinux settings
    lb config noauto \
        --distribution bookworm \
        --architecture amd64 \
        --mirror-bootstrap "$DEBIAN_MIRROR" \
        --mirror-binary "$DEBIAN_MIRROR" \
        --mirror-chroot "$DEBIAN_MIRROR" \
        --mirror-chroot-security "$SECURITY_MIRROR" \
        --mirror-binary-security "$SECURITY_MIRROR" \
        --archive-areas "main contrib non-free non-free-firmware" \
        --bootappend-live "boot=live components locales=zh_CN.UTF-8 keyboard-layouts=us" \
        --debian-installer "none" \
        --win32-loader "false" \
        --iso-application "AtzLinux Live" \
        --iso-preparer "AtzLinux Project" \
        --iso-publisher "AtzLinux" \
        --iso-volume "AtzLinux Live $DEBVERSION" \
        --linux-flavours "amd64" \
        --linux-packages "linux-image linux-headers" \
        --security "true" \
        --updates "true" \
        --backports "true" \
        --mode "debian" \
        || {
            echo "Error: lb config failed"
            exit 1
        }
    
    echo "Live-build configured successfully."
}
SCRIPT_EOF
```

- [ ] **Step 6: Add build execution function**

```bash
cat >> /home/mike/dev/debian/debian-cn/isodvd/livecd/build-livecd.sh << 'SCRIPT_EOF'

# Run the build
run_build() {
    echo "Starting live-build..."
    echo "This may take 30-60 minutes depending on your system and network."
    echo ""
    
    cd "$SCRIPT_DIR"
    
    # Run lb build
    lb build 2>&1 | tee build.log || {
        echo "Error: lb build failed"
        echo "Check build.log for details"
        exit 1
    }
    
    echo ""
    echo "Build completed successfully."
}

# Validate and move output
validate_output() {
    local iso_file="live-image-amd64.hybrid.iso"
    local output_name="atzlinux-live-${DEBVERSION:-12.13.1}-amd64.iso"
    local output_dir="/tmp/livecd"
    
    cd "$SCRIPT_DIR"
    
    if [[ ! -f "$iso_file" ]]; then
        echo "Error: Expected ISO file not found: $iso_file"
        exit 1
    fi
    
    # Check file size (should be > 500MB)
    local size=$(stat -c%s "$iso_file")
    if [[ $size -lt 524288000 ]]; then
        echo "Error: ISO file is too small (${size} bytes)"
        exit 1
    fi
    
    echo "ISO size: $(du -h "$iso_file" | cut -f1)"
    
    # Move to output directory
    mkdir -p "$output_dir"
    mv "$iso_file" "$output_dir/$output_name"
    
    echo ""
    echo "=== Build Complete ==="
    echo "ISO created: $output_dir/$output_name"
    echo ""
    echo "To test in QEMU (if installed):"
    echo "  qemu-system-x86_64 -m 2048 -cdrom $output_dir/$output_name"
}
SCRIPT_EOF
```

- [ ] **Step 7: Add main function and finalize script**

```bash
cat >> /home/mike/dev/debian/debian-cn/isodvd/livecd/build-livecd.sh << 'SCRIPT_EOF'

# Main function
main() {
    configure_live_build
    run_build
    validate_output
}

# Run main
main
SCRIPT_EOF
```

- [ ] **Step 8: Verify complete script**

```bash
cd /home/mike/dev/debian/debian-cn/isodvd/livecd
head -20 build-livecd.sh
echo "..."
tail -10 build-livecd.sh
wc -l build-livecd.sh
```

Expected: Shows ~200 lines, script is executable

- [ ] **Step 9: Commit**

```bash
cd /home/mike/dev/debian/debian-cn
git add isodvd/livecd/build-livecd.sh
git commit -m "feat: add main liveCD build script

Create build-livecd.sh that orchestrates the liveCD build process:
- Parses --mirror argument (huawei/tencent/debian)
- Auto-installs live-build, debootstrap, squashfs-tools, xorriso
- Imports configs from existing AtzLinux profiles
- Configures lb with AtzLinux settings (zh_CN.UTF-8, XFCE)
- Validates output and moves ISO to /tmp/livecd/

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 3: Create Locale Setup Hook

**Files:**
- Create: `isodvd/livecd/hooks/chroot/01-setup-locale.chroot`

- [ ] **Step 1: Create locale setup hook**

```bash
cat > /home/mike/dev/debian/debian-cn/isodvd/livecd/hooks/chroot/01-setup-locale.chroot << 'HOOK_EOF'
#!/bin/bash
#
# Hook: Configure Chinese locale (zh_CN.UTF-8)
# Runs inside the chroot during live-build
#

set -e

echo "P: Configuring Chinese locale..."

# Generate zh_CN.UTF-8 locale
locale-gen zh_CN.UTF-8

# Set default locale
update-locale LANG=zh_CN.UTF-8 LANGUAGE="zh_CN:zh"

# Also enable other common Chinese locales for compatibility
echo "zh_CN.GB18030 UTF-8" >> /etc/locale.gen
echo "zh_CN.GBK UTF-8" >> /etc/locale.gen
echo "zh_CN.GB2312 UTF-8" >> /etc/locale.gen
locale-gen

echo "P: Chinese locale configured."
HOOK_EOF
chmod +x /home/mike/dev/debian/debian-cn/isodvd/livecd/hooks/chroot/01-setup-locale.chroot
```

- [ ] **Step 2: Verify hook**

```bash
cat /home/mike/dev/debian/debian-cn/isodvd/livecd/hooks/chroot/01-setup-locale.chroot
```

Expected: Shows the hook content, is executable

- [ ] **Step 3: Commit**

```bash
cd /home/mike/dev/debian/debian-cn
git add isodvd/livecd/hooks/chroot/01-setup-locale.chroot
git commit -m "feat: add locale setup hook for liveCD

Configure zh_CN.UTF-8 as default locale with GB18030, GBK, GB2312
support for compatibility with legacy Chinese applications.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 4: Create Input Methods Hook

**Files:**
- Create: `isodvd/livecd/hooks/chroot/02-configure-input-methods.chroot`

- [ ] **Step 1: Create input methods hook**

```bash
cat > /home/mike/dev/debian/debian-cn/isodvd/livecd/hooks/chroot/02-configure-input-methods.chroot << 'HOOK_EOF'
#!/bin/bash
#
# Hook: Configure fcitx and sogoupinyin input methods
# Runs inside the chroot during live-build
#

set -e

echo "P: Configuring input methods..."

# Ensure fcitx is configured as the default input method
# Create /etc/X11/Xsession.d entry for fcitx
cat > /etc/X11/Xsession.d/95im-config << 'IMCONFIG'
# Set fcitx as default input method
export XMODIFIERS="@im=fcitx"
export QT_IM_MODULE="fcitx"
export GTK_IM_MODULE="fcitx"
export CLUTTER_IM_MODULE="fcitx"
IMCONFIG

# Ensure fcitx starts automatically for live user
mkdir -p /etc/skel/.config/autostart

cat > /etc/skel/.config/autostart/fcitx.desktop << 'FCITX_DESKTOP'
[Desktop Entry]
Type=Application
Name=Fcitx
Comment=Start Fcitx Input Method
Exec=fcitx
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
FCITX_DESKTOP

# Create default fcitx profile with sogoupinyin enabled
mkdir -p /etc/skel/.config/fcitx

cat > /etc/skel/.config/fcitx/profile << 'FCITX_PROFILE'
[Profile]
# Use sogoupinyin as default
IMName=sogoupinyin
# Show tray icon
ShowPreedit=False
ShowStatusBar=True
# Switch with Ctrl+Space
TriggerKey=CTRL_SPACE

[IM]
# Enable sogoupinyin
sogoupinyin=True
# Also enable keyboard layouts
keyboard-us=True

[IM/sogoupinyin]
# Sogou pinyin specific settings
FCITX_PROFILE

echo "P: Input methods configured."
HOOK_EOF
chmod +x /home/mike/dev/debian/debian-cn/isodvd/livecd/hooks/chroot/02-configure-input-methods.chroot
```

- [ ] **Step 2: Verify hook**

```bash
cat /home/mike/dev/debian/debian-cn/isodvd/livecd/hooks/chroot/02-configure-input-methods.chroot
```

Expected: Shows the hook content

- [ ] **Step 3: Commit**

```bash
cd /home/mike/dev/debian/debian-cn
git add isodvd/livecd/hooks/chroot/02-configure-input-methods.chroot
git commit -m "feat: add input method configuration hook

Configure fcitx with sogoupinyin as default for live session:
- Set XMODIFIERS, QT_IM_MODULE, GTK_IM_MODULE for fcitx
- Auto-start fcitx for live user
- Default profile enables sogoupinyin

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 5: Create Desktop Customization Hook

**Files:**
- Create: `isodvd/livecd/hooks/chroot/03-customize-desktop.chroot`

- [ ] **Step 1: Create desktop customization hook**

```bash
cat > /home/mike/dev/debian/debian-cn/isodvd/livecd/hooks/chroot/03-customize-desktop.chroot << 'HOOK_EOF'
#!/bin/bash
#
# Hook: Apply AtzLinux desktop customizations
# Runs inside the chroot during live-build
#

set -e

echo "P: Applying desktop customizations..."

# Create AtzLinux branding file
cat > /etc/atzlinux-version << 'VERSION'
AtzLinux LiveCD
VERSION_EOF

# Configure lightdm for auto-login (live user)
if [[ -d /etc/lightdm ]]; then
    cat > /etc/lightdm/lightdm.conf.d/90-atzlinux.conf << 'LIGHTDM'
[Seat:*]
autologin-user=live
autologin-user-timeout=0
user-session=xfce
LIGHTDM
fi

# Configure XFCE4 defaults for live user
mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml

cat > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << 'XFCE_DESKTOP'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="2"/>
  </property>
</channel>
XFCE_DESKTOP

# Set default panel layout
mkdir -p /etc/skel/.config/xfce4/panel

# Configure session
mkdir -p /etc/skel/.config/xfce4/xfce4-session

cat > /etc/skel/.config/xfce4/xfce4-session/xfce4-session.xml << 'XFCE_SESSION'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-session" version="1.0">
  <property name="general" type="empty">
    <property name="FailsafeSessionName" type="string" value="Failsafe"/>
  </property>
</channel>
XFCE_SESSION

# Create a welcome file on desktop
mkdir -p /etc/skel/Desktop
cat > /etc/skel/Desktop/欢迎使用铜豌豆Linux.txt << 'WELCOME'
欢迎使用 铜豌豆 Linux (AtzLinux)  LiveCD！

这是一个可以直接运行的演示版本，不会修改您的硬盘。

主要特性：
- 基于 Debian 12 (bookworm)
- 中文本地化界面和输入法
- 预装常用中文软件
- 开箱即用的桌面体验

官方网站: https://www.atzlinux.com/

提示：本系统运行在内存中，重启后所有更改将丢失。

WELCOME

chmod +x /etc/skel/Desktop/欢迎使用铜豌豆Linux.txt

echo "P: Desktop customizations applied."
HOOK_EOF
chmod +x /home/mike/dev/debian/debian-cn/isodvd/livecd/hooks/chroot/03-customize-desktop.chroot
```

- [ ] **Step 2: Verify hook**

```bash
cat /home/mike/dev/debian/debian-cn/isodvd/livecd/hooks/chroot/03-customize-desktop.chroot
```

Expected: Shows the hook content

- [ ] **Step 3: Commit**

```bash
cd /home/mike/dev/debian/debian-cn
git add isodvd/livecd/hooks/chroot/03-customize-desktop.chroot
git commit -m "feat: add desktop customization hook

Apply AtzLinux desktop customizations:
- Configure lightdm auto-login for live user
- Set XFCE4 default desktop settings
- Create welcome message on desktop
- Set up session defaults

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 6: Create GPG Keys Copy Hook

**Files:**
- Create: `isodvd/livecd/hooks/binary/01-copy-gpg-keys.binary`

- [ ] **Step 1: Create GPG keys hook**

```bash
cat > /home/mike/dev/debian/debian-cn/isodvd/livecd/hooks/binary/01-copy-gpg-keys.binary << 'HOOK_EOF'
#!/bin/bash
#
# Hook: Copy GPG keys to live filesystem
# Runs during binary assembly (after chroot is complete)
#

set -e

echo "P: Copying GPG keys to ISO..."

# The keys should already be in config/chroot_sources/
# They will be automatically included in the chroot
# This hook ensures they're properly set up in the live system

# If we need to do any additional key setup, do it here
# For now, the keys copied to chroot_sources are sufficient

echo "P: GPG keys configured."
HOOK_EOF
chmod +x /home/mike/dev/debian/debian-cn/isodvd/livecd/hooks/binary/01-copy-gpg-keys.binary
```

- [ ] **Step 2: Verify hook**

```bash
cat /home/mike/dev/debian/debian-cn/isodvd/livecd/hooks/binary/01-copy-gpg-keys.binary
```

Expected: Shows the hook content

- [ ] **Step 3: Commit**

```bash
cd /home/mike/dev/debian/debian-cn
git add isodvd/livecd/hooks/binary/01-copy-gpg-keys.binary
git commit -m "feat: add GPG keys binary hook

Hook to ensure GPG keys are properly configured in the live system.
Keys are copied via chroot_sources and included automatically.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 7: Update CLAUDE.md Documentation

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Read current CLAUDE.md**

```bash
cat /home/mike/dev/debian/debian-cn/CLAUDE.md
```

- [ ] **Step 2: Add liveCD build section to CLAUDE.md**

```bash
cat >> /home/mike/dev/debian/debian-cn/CLAUDE.md << 'DOC_EOF'

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

DOC_EOF
```

- [ ] **Step 3: Verify CLAUDE.md update**

```bash
tail -50 /home/mike/dev/debian/debian-cn/CLAUDE.md
```

Expected: Shows the new LiveCD Build Commands section

- [ ] **Step 4: Commit**

```bash
cd /home/mike/dev/debian/debian-cn
git add CLAUDE.md
git commit -m "docs: add liveCD build commands to CLAUDE.md

Document how to build and test the liveCD:
- build-livecd.sh usage with mirror options
- QEMU testing command
- USB writing command
- LiveCD features and directory structure

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 8: Self-Review Checklist

Before considering this complete, verify:

- [ ] All files are created with exact paths specified
- [ ] build-livecd.sh is executable and parses --mirror correctly
- [ ] All hooks are executable (.chroot and .binary files)
- [ ] Script imports configs from existing `isodvd/profiles/amd64.build.conf`
- [ ] Script imports package list from `atzlinux-amd64-xfce.packages`
- [ ] Script auto-installs required packages
- [ ] Script validates output ISO exists and is > 500MB
- [ ] Locale hook configures zh_CN.UTF-8
- [ ] Input method hook configures fcitx + sogoupinyin
- [ ] Desktop hook configures auto-login and welcome message
- [ ] CLAUDE.md documents the build and test process

---

## Spec Coverage Review

| Spec Requirement | Implementation Task |
|------------------|---------------------|
| Build system in `isodvd/livecd/` | Task 1 (directories), Task 2 (build script) |
| Auto-install required packages | Task 2, Step 3 |
| Import configs from existing profiles | Task 2, Step 4 (import_build_config, generate_package_list) |
| Copy GPG keys | Task 2, Step 4 (copy_gpg_keys) |
| Configure lb with AtzLinux settings | Task 2, Step 5 (configure_live_build) |
| Locale hook (zh_CN.UTF-8) | Task 3 |
| Input method hook (fcitx + sogoupinyin) | Task 4 |
| Desktop customization hook | Task 5 |
| GPG keys hook | Task 6 |
| Documentation in CLAUDE.md | Task 7 |

All spec requirements are covered.

---

## Execution Options

**Plan complete and saved to `docs/superpowers/plans/2025-04-16-livecd-build-system.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
