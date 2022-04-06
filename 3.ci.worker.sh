#!/usr/bin/env bash

#打开执行过程显示
set -x
#显示设置环境变量 CMD_PATH当前脚本所在目录
export CMD_PATH=$(cd `dirname $0`; pwd)
export PROJECT_NAME="${CMD_PATH##*/}"
echo $PROJECT_NAME
cd $CMD_PATH
apt install simple-cdd -y
cd isodvd
rm -rf tmp/mirror/db/lockfile
./amd64.build.sh

# 1007.4.deb.control.gen.sh
# 1007.5.deb.make.sh
# 1007.6.deb.install.sh

# 1007.19.docker.build.sh
# 1007.20.docker.push.sh
# 1007.21.kompose.convert.sh
# 1007.22.k8s.deploy.dev.sh

# 1007.23.k8s.deploy.qingdao.sh
