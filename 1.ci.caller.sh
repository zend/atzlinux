#!/usr/bin/env bash
set +x
export CMD_PATH=$(cd `dirname $0`; pwd)
cd $CMD_PATH
./2.ci.expect.sh
