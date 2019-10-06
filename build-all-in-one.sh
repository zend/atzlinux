#!/bin/bash

VDATE=`git log -1 --pretty=format:"%ad" --date=short`

git log -1 > all-in-one.version.$VDATE.txt

tar czvf /tmp/debian-cn.tar.gz --exclude=".git"  *
