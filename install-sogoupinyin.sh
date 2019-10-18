#!/bin/bash
cd sogoupinyin
cd `dirname $0`; pwd
echo '即将开始安装 ...'

URL="http://cdn2.ime.sogou.com/dl/index/1571302197/sogoupinyin_2.3.1.0112_amd64.deb?st=x_sbxD4RrG1tvywaRYDD_Q&e=1571370757&fn=sogoupinyin_2.3.1.0112_amd64.deb"

FILENAME=`echo $URL|awk -F "=" {'print $NF'}`

wget -c -O $FILENAME $URL

apt -y install ./$FILENAME

rm -fv /etc/apt/sources.list.d/sogoupinyin.list

cd ..

echo '搜狗拼音输入法安装完成后，需要退出当前登录的图像界面，再重新登录，才能够让搜狗输入法生效。'
