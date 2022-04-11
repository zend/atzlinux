#!/usr/bin/env bash

set -x

export atzlinux_debian_mirror_extra=${atzlinux_debian_mirror_extra:="https://apt.atzlinux.com/atzlinux"}
export atzlinux_debian_security_mirror=${atzlinux_debian_security_mirror:="https://mirrors.huaweicloud.com/debian-security/ "}
export atzlinux_debian_mirror=${atzlinux_debian_mirror:="https://mirrors.huaweicloud.com/debian/"}

build-simple-cdd --force-root \
--debug  \
--dvd \
--dist buster \
--locale zh_CN \
--keyboard us  \
--security-mirror ${atzlinux_debian_security_mirror} \
--debian-mirror ${atzlinux_debian_mirror}  \
-b amd64.build
