#!/bin/bash
#
# AtzLinux LiveCD Build Script
# Builds a live demo ISO using live-build
#

set -e

# Get script directory (suppress set -e tracing)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISODVD_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$ISODVD_DIR")"

# Default values
MIRROR="ustc"
DEBIAN_MIRROR="https://mirrors.ustc.edu.cn/debian/"
SECURITY_MIRROR="https://mirrors.ustc.edu.cn/debian-security/"
KEEP_ARTIFACTS=false
QUIET=false

# Cleanup function - removes build artifacts
cleanup() {
    local exit_code=$?
    cd "$SCRIPT_DIR"

    if [[ "$KEEP_ARTIFACTS" == true ]]; then
        echo ""
        echo "=== Preserving build artifacts (--keep specified) ==="
        echo "Build artifacts left in: $SCRIPT_DIR"
        echo "To clean up manually, run: sudo rm -rf config chroot cache .build local"
        exit $exit_code
    fi

    echo ""
    echo "=== Cleaning up build artifacts ==="

    # Remove generated build directories and files
    rm -rf config/ 2>/dev/null || true
    rm -rf chroot/ 2>/dev/null || true
    rm -rf cache/ 2>/dev/null || true
    rm -rf .build/ 2>/dev/null || true
    rm -rf local/ 2>/dev/null || true
    rm -f chroot.headers 2>/dev/null || true
    rm -f chroot.packages.* 2>/dev/null || true
    rm -f binary.* 2>/dev/null || true
    rm -f live-image-*.* 2>/dev/null || true

    # Remove log files (keep build.log for reference if build succeeded)
    if [[ $exit_code -ne 0 ]]; then
        rm -f build.log 2>/dev/null || true
    fi

    echo "Cleanup complete."
    exit $exit_code
}

# Cleanup function for errors - preserves logs for debugging
cleanup_on_error() {
    local exit_code=$?
    local line_no=$1

    echo ""
    echo "=== Build failed at line $line_no (exit code: $exit_code) ==="

    if [[ "$KEEP_ARTIFACTS" == true ]]; then
        echo "Build artifacts preserved for debugging (--keep specified)"
        exit $exit_code
    fi

    echo "Preserving build.log for debugging..."
    if [[ -f "$SCRIPT_DIR/build.log" ]]; then
        mv "$SCRIPT_DIR/build.log" "$SCRIPT_DIR/build-failed-$(date +%Y%m%d-%H%M%S).log" 2>/dev/null || true
        echo "Log saved to: build-failed-*.log"
    fi

    # Perform normal cleanup
    cd "$SCRIPT_DIR"
    rm -rf config/ chroot/ cache/ .build/ local/ 2>/dev/null || true
    rm -f chroot.headers chroot.packages.* binary.* live-image-*.* 2>/dev/null || true

    echo "Cleanup complete. Check the saved log for error details."
    exit $exit_code
}

# Initial cleanup - remove any leftover artifacts from previous runs
initial_cleanup() {
    echo "Checking for leftover build artifacts..."

    cd "$SCRIPT_DIR"

    local found=false
    for item in config chroot cache .build local chroot.headers chroot.packages.* binary.* live-image-*.*; do
        if [[ -e "$item" ]]; then
            found=true
            break
        fi
    done

    if [[ "$found" == true ]]; then
        echo "Found leftover artifacts from previous build. Cleaning up..."
        rm -rf config/ chroot/ cache/ .build/ local/ 2>/dev/null || true
        rm -f chroot.headers chroot.packages.* binary.* live-image-*.* 2>/dev/null || true
        echo "Initial cleanup complete."
    else
        echo "No leftover artifacts found."
    fi
}

# Set up error handling traps
setup_traps() {
    # Trap errors and call cleanup_on_error with the line number
    trap 'cleanup_on_error $LINENO' ERR

    # Trap interrupts (Ctrl+C) and call normal cleanup
    trap 'echo ""; echo "Build interrupted by user"; cleanup' INT TERM
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mirror)
            MIRROR="$2"
            shift 2
            ;;
        --keep)
            KEEP_ARTIFACTS=true
            shift
            ;;
        --quiet|-q)
            QUIET=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--mirror ustc|huawei|tencent|debian] [--keep] [--quiet]"
            echo ""
            echo "Options:"
            echo "  --mirror    Mirror to use (default: ustc)"
            echo "  --keep      Keep build artifacts after completion (for debugging)"
            echo "  --quiet     Suppress verbose output, only show warnings/errors"
            echo "  --help      Show this help message"
            echo ""
            echo "Examples:"
            echo "  sudo $0                              # Build with USTC mirror (default)"
            echo "  sudo $0 --mirror huawei              # Build with Huawei mirror"
            echo "  sudo $0 --mirror tencent             # Build with Tencent mirror"
            echo "  sudo $0 --mirror debian              # Build with official Debian mirror"
            echo "  sudo $0 --keep                       # Keep artifacts for debugging"
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
    ustc)
        DEBIAN_MIRROR="https://mirrors.ustc.edu.cn/debian"
        SECURITY_MIRROR="https://mirrors.ustc.edu.cn/debian-security"
        ;;
    huawei)
        DEBIAN_MIRROR="https://mirrors.huaweicloud.com/debian"
        SECURITY_MIRROR="https://mirrors.huaweicloud.com/debian-security"
        ;;
    tencent)
        DEBIAN_MIRROR="https://mirrors.tencent.com/debian"
        SECURITY_MIRROR="https://mirrors.tencent.com/debian-security"
        ;;
    debian)
        DEBIAN_MIRROR="https://deb.debian.org/debian"
        SECURITY_MIRROR="https://security.debian.org/debian-security"
        ;;
esac

echo "=== AtzLinux LiveCD Build ==="
echo "Mirror: $MIRROR"
echo "Debian Mirror: $DEBIAN_MIRROR"
echo ""

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root (for live-build)"
    echo "Usage: sudo $0 [--mirror ustc|huawei|tencent|debian] [--keep]"
    exit 1
fi

# Auto-install required packages
echo "Checking required packages..."
REQUIRED_PKGS="live-build debootstrap squashfs-tools xorriso syslinux-utils"
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
    local packages_file="$ISODVD_DIR/profiles/atzlinux-amd64-xfce-mini.packages"
    local output_file="$SCRIPT_DIR/config/package-lists/atzlinux-packages.list"

    if [[ ! -f "$packages_file" ]]; then
        echo "Error: Package list not found: $packages_file"
        exit 1
    fi

    if [[ "$QUIET" != true ]]; then
        echo "Generating package list from $packages_file..."
    fi

    # Create package-lists directory
    mkdir -p "$SCRIPT_DIR/config/package-lists"

    # Copy packages, filtering out comments and empty lines
    grep -v "^[[:space:]]*#" "$packages_file" | grep -v "^[[:space:]]*$" > "$output_file"

    # Add syslinux-utils for isohybrid (needed for hybrid ISO creation)
    echo "syslinux-utils" >> "$output_file"

    if [[ "$QUIET" != true ]]; then
        echo "Package list written to $output_file"
    fi
}

# Copy GPG keys
copy_gpg_keys() {
    local keys_dir="$PROJECT_DIR/etc/apt/trusted.gpg.d"
    local output_dir="$SCRIPT_DIR/config/chroot_sources"

    if [[ ! -d "$keys_dir" ]]; then
        echo "Warning: GPG keys directory not found: $keys_dir"
        return
    fi

    if [[ "$QUIET" != true ]]; then
        echo "Copying GPG keys..."
    fi

    # Create chroot_sources directory
    mkdir -p "$output_dir"

    # Copy all .gpg and .asc files
    for key in "$keys_dir"/*.gpg "$keys_dir"/*.asc; do
        if [[ -f "$key" ]]; then
            cp "$key" "$output_dir/"
            if [[ "$QUIET" != true ]]; then
                echo "  Copied: $(basename "$key")"
            fi
        fi
    done

    # Copy AtzLinux keyring from host system if installed
    if [[ -f /usr/share/keyrings/atzlinux-archive-keyring.gpg ]]; then
        cp /usr/share/keyrings/atzlinux-archive-keyring.gpg "$output_dir/"
        if [[ "$QUIET" != true ]]; then
            echo "  Copied: atzlinux-archive-keyring.gpg (from host)"
        fi
    elif [[ -f /etc/apt/trusted.gpg.d/atzlinux-archive-keyring.gpg ]]; then
        cp /etc/apt/trusted.gpg.d/atzlinux-archive-keyring.gpg "$output_dir/"
        if [[ "$QUIET" != true ]]; then
            echo "  Copied: atzlinux-archive-keyring.gpg (from host apt)"
        fi
    else
        echo "Warning: AtzLinux keyring not found on host system"
    fi
}

# Copy hooks
copy_hooks() {
    local hooks_dir="$SCRIPT_DIR/hooks"

    if [[ ! -d "$hooks_dir" ]]; then
        echo "Warning: Hooks directory not found: $hooks_dir"
        return
    fi

    if [[ "$QUIET" != true ]]; then
        echo "Copying hooks..."
    fi

    # Copy chroot hooks
    if [[ -d "$hooks_dir/chroot" ]]; then
        mkdir -p config/hooks/normal
        for hook in "$hooks_dir/chroot"/*.chroot; do
            if [[ -f "$hook" ]]; then
                cp "$hook" config/hooks/normal/
                if [[ "$QUIET" != true ]]; then
                    echo "  Copied chroot hook: $(basename "$hook")"
                fi
            fi
        done
    fi

    # Copy binary hooks
    if [[ -d "$hooks_dir/binary" ]]; then
        mkdir -p config/hooks/binary
        for hook in "$hooks_dir/binary"/*.binary; do
            if [[ -f "$hook" ]]; then
                cp "$hook" config/hooks/binary/
                if [[ "$QUIET" != true ]]; then
                    echo "  Copied binary hook: $(basename "$hook")"
                fi
            fi
        done
    fi
}

# Configure live-build
configure_live_build() {
    echo "Configuring live-build..."

    cd "$SCRIPT_DIR"

    # Import build config to get DEBVERSION
    import_build_config

    # Clean up any leftover config directories from previous lb config runs
    rm -rf config/binary config/bootstrap config/chroot config/source 2>/dev/null || true

    # Run lb config with AtzLinux settings
    # Note: Disable security repository since third-party mirrors use different naming
    # Security updates are included in the main mirror
    if [[ "$QUIET" == true ]]; then
        lb config noauto \
            --distribution bookworm \
            --architecture amd64 \
            --mirror-bootstrap "$DEBIAN_MIRROR" \
            --mirror-binary "$DEBIAN_MIRROR" \
            --mirror-chroot "$DEBIAN_MIRROR" \
            --mirror-chroot-security "$DEBIAN_MIRROR" \
            --mirror-chroot-backports "$DEBIAN_MIRROR" \
            --mirror-binary-security "$DEBIAN_MIRROR" \
            --mirror-binary-backports "$DEBIAN_MIRROR" \
            --archive-areas "main contrib non-free non-free-firmware" \
            --bootappend-live "boot=live components locales=zh_CN.UTF-8 keyboard-layouts=us" \
            --debian-installer "false" \
            --win32-loader "false" \
            --iso-application "AtzLinux Live" \
            --iso-preparer "AtzLinux Project" \
            --iso-publisher "AtzLinux" \
            --iso-volume "AtzLinux Live $DEBVERSION" \
            --linux-flavours "amd64" \
            --linux-packages "linux-image linux-headers" \
            --security "false" \
            --firmware-chroot "false" \
            --cache "false" \
            --bootloader "grub" \
            --memtest "none" \
            --mode "debian" \
            > /dev/null \
            || {
                echo "Error: lb config failed"
                exit 1
            }
    else
        lb config noauto \
            --distribution bookworm \
            --architecture amd64 \
            --mirror-bootstrap "$DEBIAN_MIRROR" \
            --mirror-binary "$DEBIAN_MIRROR" \
            --mirror-chroot "$DEBIAN_MIRROR" \
            --mirror-chroot-security "$DEBIAN_MIRROR" \
            --mirror-chroot-backports "$DEBIAN_MIRROR" \
            --mirror-binary-security "$DEBIAN_MIRROR" \
            --mirror-binary-backports "$DEBIAN_MIRROR" \
            --archive-areas "main contrib non-free non-free-firmware" \
            --bootappend-live "boot=live components locales=zh_CN.UTF-8 keyboard-layouts=us" \
            --debian-installer "false" \
            --win32-loader "false" \
            --iso-application "AtzLinux Live" \
            --iso-preparer "AtzLinux Project" \
            --iso-publisher "AtzLinux" \
            --iso-volume "AtzLinux Live $DEBVERSION" \
            --linux-flavours "amd64" \
            --linux-packages "linux-image linux-headers" \
            --security "false" \
            --firmware-chroot "false" \
            --cache "false" \
            --bootloader "grub" \
            --memtest "none" \
            --mode "debian" \
            || {
                echo "Error: lb config failed"
                exit 1
            }
    fi

    # Disable security repository in apt sources (Huawei mirror uses different naming)
    sed -i 's/\.\/debian-security/# .\/debian-security/' config/chroot_apt/apt.conf 2>/dev/null || true
    sed -i 's/bookworm\/updates/# bookworm\/updates/' config/chroot/sources.list 2>/dev/null || true

    # Allow files larger than 4GiB in ISO (ISO-9660 limitation)
    # GENISOIMAGE_OPTIONS_EXTRA is defined in config/common file
    sed -i 's/GENISOIMAGE_OPTIONS_EXTRA=""/GENISOIMAGE_OPTIONS_EXTRA="-allow-limited-size"/' config/common

    # Fix LB_INITRAMFS - set to initramfs-tools instead of auto to avoid "auto" package error
    sed -i 's/LB_INITRAMFS="auto"/LB_INITRAMFS="initramfs-tools"/' config/common

    # Create directories for additional files (these are actual directories)
    mkdir -p config/chroot_sources config/chroot_apt

    # Setup AtzLinux repository in config/archives (processed before package installation)
    mkdir -p config/archives

    # Copy AtzLinux keyring from host (required for apt to trust the repository)
    if [[ -f /usr/share/keyrings/atzlinux-archive-keyring.gpg ]]; then
        cp /usr/share/keyrings/atzlinux-archive-keyring.gpg config/archives/atzlinux.key
        if [[ "$QUIET" != true ]]; then
            echo "  Copied AtzLinux keyring to archives"
        fi
    elif [[ -f /etc/apt/trusted.gpg.d/atzlinux-archive-keyring.gpg ]]; then
        cp /etc/apt/trusted.gpg.d/atzlinux-archive-keyring.gpg config/archives/atzlinux.key
        if [[ "$QUIET" != true ]]; then
            echo "  Copied AtzLinux keyring from apt to archives"
        fi
    else
        echo "  Warning: AtzLinux keyring not found on host system"
    fi

    # Create AtzLinux sources list (without signed-by since key is in trusted.gpg.d)
    cat > config/archives/atzlinux.list.chroot << 'EOF'
deb http://deb.atzlinux.com:60000/atzlinux bookworm main contrib non-free non-free-firmware
deb https://apt.atzlinux.com/atzlinux bookworm main
EOF
    if [[ "$QUIET" != true ]]; then
        echo "  Created AtzLinux sources list in archives"
    fi

    # Add apt-utils to binary packages (needed for apt-ftparchive during ISO creation)
    mkdir -p config/package-lists
    echo "apt-utils" > config/package-lists/apt-utils.list.binary
    if [[ "$QUIET" != true ]]; then
        echo "  Added apt-utils to binary packages"
    fi

    # Generate package list
    generate_package_list

    # Copy GPG keys
    copy_gpg_keys

    # Copy hooks
    copy_hooks

    echo "Live-build configured successfully."
}

# Run the build
run_build() {
    echo "Starting live-build..."
    if [[ "$QUIET" != true ]]; then
        echo "This may take 30-60 minutes depending on your system and network."
    fi

    cd "$SCRIPT_DIR"

    # Run lb build - log is handled by cleanup functions
    # In quiet mode, suppress verbose debootstrap/apt output but keep errors visible
    if [[ "$QUIET" == true ]]; then
        lb build > build.log 2>&1 || {
            echo "Error: lb build failed. Check build.log for details."
            tail -50 build.log
            exit 1
        }
    else
        lb build 2>&1 | tee build.log || {
            echo "Error: lb build failed"
            exit 1
        }
    fi

    echo ""
    echo "Build completed successfully."
}

# Validate and move output
validate_output() {
    # live-build creates the ISO in different locations depending on bootloader
    local iso_file="chroot/binary.hybrid.iso"
    if [[ ! -f "$iso_file" ]]; then
        iso_file="live-image-amd64.hybrid.iso"
    fi
    local output_name="atzlinux-live-${DEBVERSION:-12.13.1}-amd64.iso"

    cd "$SCRIPT_DIR"

    if [[ ! -f "$iso_file" ]]; then
        echo "Error: Expected ISO file not found: $iso_file"
        exit 1
    fi

    # Check file size (should be > 100MB for a minimal live system)
    local size=$(stat -c%s "$iso_file")
    if [[ $size -lt 104857600 ]]; then
        echo "Error: ISO file is too small (${size} bytes)"
        exit 1
    fi

    echo "ISO size: $(du -h "$iso_file" | cut -f1)"

    # Rename ISO in current directory (same partition, no copy needed)
    mv "$iso_file" "$output_name"

    echo ""
    echo "=== Build Complete ==="
    echo "ISO created: $SCRIPT_DIR/$output_name"
    echo ""
    echo "To test in QEMU (if installed):"
    echo "  qemu-system-x86_64 -m 2048 -cdrom $SCRIPT_DIR/$output_name"
}

# Main function
main() {
    # Set up error handling traps first
    setup_traps

    # Clean up any leftover artifacts from previous runs
    initial_cleanup

    configure_live_build
    run_build
    validate_output
}

# Run main
main
