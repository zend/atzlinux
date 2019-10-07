#!/bin/bash

VDATE=`git log -1 --pretty=format:"%ad" --date=short`

rm -fv all-in-one.version.*.txt
git log -1 > all-in-one.version.$VDATE.txt

tar czvf /tmp/debian-cn.tar.gz --exclude=".git*" ../debian-cn
