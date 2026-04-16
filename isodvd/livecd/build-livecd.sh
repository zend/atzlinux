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

# Main function
main() {
    configure_live_build
    run_build
    validate_output
}

# Run main
main
