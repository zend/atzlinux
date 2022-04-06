#!/usr/bin/env bash

export CMD_PATH=$(cd `dirname $0`; pwd)
export PROJECT_NAME="${CMD_PATH##*/}"
echo $PROJECT_NAME
cd $CMD_PATH
apt install simple-cdd -y
cd isodvd
rm -rf tmp/mirror/db/lockfile
export atzlinux_debian_mirror_extra="https://apt.atzlinux.com/atzlinux"
export atzlinux_debian_security_mirror="https://mirrors.huaweicloud.com/debian-security/ "
export atzlinux_debian_mirror="https://mirrors.huaweicloud.com/debian/"
./amd64.build.sh
