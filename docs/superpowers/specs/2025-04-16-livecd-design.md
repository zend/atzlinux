# AtzLinux LiveCD Build System Design

## Summary

A build system for creating a liveCD/demo ISO of AtzLinux that boots directly into a running XFCE desktop with the same Chinese-localized experience as an installed system.

## Context

Currently AtzLinux uses `simple-cdd` to build installer ISOs. Users want to try the desktop environment before committing to installation. This liveCD will provide a demo/try-before-install experience without persistence.

## Goals

- Boot directly to XFCE desktop with AtzLinux Chinese localization
- Include same packages as `atzlinux-amd64-xfce` installer profile
- Reuse existing AtzLinux configurations (apt sources, GPG keys, preseed settings)
- No persistence (pure live session)
- Simple build process: `sudo ./build-livecd.sh`

## Non-Goals

- LiveCD with persistence (separate feature, could be added later)
- Multiple DE variants (start with XFCE only)
- Replace installer ISO (complements it)

## Design

### Architecture Overview

The liveCD build system is a wrapper around Debian's `live-build` tool that automatically imports AtzLinux's existing configuration.

**Location**: `isodvd/livecd/` directory alongside the existing installer build system.

**Key Design Decisions**:
- Uses `live-build` (lb_config, lb_build) commands internally
- Imports package lists from existing `isodvd/profiles/atzlinux-amd64-xfce.packages`
- Reuses apt sources from `etc/apt/sources.list.d/` and `etc/apt/trusted.gpg.d/`
- Applies the same locale settings (zh_CN.UTF-8) and keyboard (US) as installer
- Outputs ISO to same location pattern as installer builds

### Components

#### 1. `isodvd/livecd/build-livecd.sh` (Main Build Script)

Entry point for building the liveCD.

**Usage**: `sudo ./build-livecd.sh [--mirror huawei|tencent|debian]`

**Mirror Options**:
- `huawei` - Use Huawei Cloud mirrors (mirrors.huaweicloud.com)
- `tencent` - Use Tencent Cloud mirrors (mirrors.tencent.com)
- `debian` - Use official Debian mirrors (deb.debian.org)
- Default: Use mirror from `amd64.build.conf`

**Responsibilities**:
- Parse command-line options
- Auto-install required packages if missing
- Import configurations from existing AtzLinux files
- Call `lb config` with AtzLinux-specific options
- Call `lb build` to generate ISO
- Validate output ISO

**Output**: `/tmp/livecd/atzlinux-live-<version>-amd64.iso`

#### 2. `isodvd/livecd/config/` (Live-Build Configuration Directory)

Live-build configuration files and directories:

- `bootstrap/` - Bootstrap settings (arch, mirror)
- `chroot/` - Chroot configuration
  - `atzlinux-packages.list.chroot` - generated from existing XFCE packages file
- `binary/` - ISO configuration (bootloader, labels)
- `common/` - Common hooks and includes
- `chroot_sources/` - GPG keys for additional repositories
- `chroot_apt/` - Apt source configurations

#### 3. `isodvd/livecd/hooks/` (Customization Scripts)

**Chroot Hooks** (run inside chroot):
- `01-setup-locale.chroot` - Set zh_CN.UTF-8, generate locales
- `02-configure-input-methods.chroot` - Setup fcitx + sogoupinyin
- `03-customize-desktop.chroot` - Apply AtzLinux desktop theme/settings

**Binary Hooks** (run during ISO assembly):
- `01-copy-gpg-keys.binary` - Copy third-party repo keys to ISO

#### 4. `isodvd/livecd/auto/` (Live-Build Automation)

- `config` - Wrapper script that calls `lb config` with all options
- `build` - Wrapper script that calls `lb build`

### Data Flow

#### Configuration Import Flow

1. `build-livecd.sh` reads `isodvd/profiles/amd64.build.conf` to get:
   - `DEBVERSION` (e.g., "12.13.1")
   - Mirror URLs (`debian_mirror`, `security_mirror`)
   - `backports_packages` list

2. Parses `isodvd/profiles/atzlinux-amd64-xfce.packages` into `config/chroot/atzlinux-packages.list.chroot`

3. Copies GPG keys from `etc/apt/trusted.gpg.d/` to `config/chroot_sources/atzlinux.chroot.gpg`

4. Generates apt source list from `etc/apt/sources.list.d/` entries

#### Build Flow

```
build-livecd.sh
├── Auto-install: live-build, debootstrap, squashfs-tools, xorriso
├── Import configs from existing AtzLinux files
├── lb config
│   ├── Set --distribution bookworm
│   ├── Set --architecture amd64
│   ├── Set --mirror-binary (from build.conf)
│   ├── Enable --archive-areas "main contrib non-free non-free-firmware"
│   └── Configure bootloader, locales, keyboard
├── Generated config copied to auto/config
└── lb build
    ├── debootstrap base system
    ├── Install packages from atzlinux-packages.list.chroot
    ├── Run chroot hooks (locale, input methods, desktop)
    ├── Run binary hooks (GPG keys)
    ├── Create squashfs filesystem
    └── Generate bootable ISO with syslinux/grub
```

### Error Handling

#### Pre-Build Validation (Fail Fast)

- Check for root privileges (`EUID == 0`)
- **Auto-install required packages**: `live-build`, `debootstrap`, `squashfs-tools`, `xorriso`
  - Uses `apt-get install -y` if packages missing
  - Exits with error only if install fails
- Check that referenced package list files exist
- Validate mirror URLs are reachable (warn if not, don't fail)

#### Build Errors

- `lb config` failures: Show configuration that failed
- `debootstrap` failures: Common if mirror is unreachable; suggest checking mirror or network
- Package install failures: Log to `build.log`, continue if non-critical (liveCD can still function)
- Hook failures: Stop build, show which hook failed with context

#### Post-Build Validation

- Verify ISO file exists and is > 500MB (sanity check)
- Check ISO can be mounted and has expected structure
- Optional: Test boot in QEMU (if available)

#### Cleanup on Failure

- Preserve `config/` and `cache/` for debugging
- Remove partial build artifacts in `build/`
- Provide `build.log` location for troubleshooting

### Testing Strategy

#### Manual Testing (Primary)

- Build ISO on clean Debian system
- Write to USB and boot on physical hardware
- Verify:
  - Boots to graphical login (or auto-login)
  - Locale is zh_CN.UTF-8
  - Input methods work (fcitx + sogoupinyin)
  - Chinese fonts display correctly
  - Network connectivity (DHCP auto-config)
  - Desktop matches installed version appearance
  - Key apps present: WPS, browser, etc.

#### Automated Validation (Optional Enhancement)

- Post-build script checks ISO structure
- Verify squashfs contains expected packages
- Check ISO boot sector is valid

#### Regression Testing

- Rebuild after any changes to `atzlinux-amd64-xfce.packages`
- Compare package list diff between builds

## Trade-offs

### Why live-build instead of extending simple-cdd?

**simple-cdd approach (rejected)**:
- Pros: Reuses existing profiles, single build system
- Cons: Not designed for liveCDs; would require hacks

**live-build approach (chosen)**:
- Pros: Official Debian tool for live systems, purpose-built, well-documented, supports XFCE well
- Cons: Separate build system; requires wrapper to import AtzLinux configs

**Decision**: Use live-build with wrapper script that imports existing AtzLinux configurations to avoid duplicating package lists and settings.

## Future Work

- Add persistence option (`--with-persistence` flag)
- Build liveCD variants for other DEs (KDE, GNOME)
- Automated ISO boot testing with QEMU
- CI/CD integration for automatic liveCD builds on release

## Open Questions

None - design is complete and ready for implementation.
