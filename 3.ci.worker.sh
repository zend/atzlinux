#!/usr/bin/env bash

export CMD_PATH=$(cd `dirname $0`; pwd)
export PROJECT_NAME="${CMD_PATH##*/}"
echo $PROJECT_NAME
cd $CMD_PATH
apt install simple-cdd -y
cd isodvd
rm -rf tmp/mirror/db/lockfile
./amd64.build.sh
