#/bin/bash

echo "remove $1 package in atzlinux-amd64-*.packages"

grep $1 atzlinux-amd64-*.packages
sed -i /$1/d atzlinux-amd64-*.packages
grep $1 atzlinux-amd64-*.packages
git diff atzlinux-amd64-*.packages
