#!/bin/bash
cd wps
cd `dirname $0`; pwd
echo '即将开始 wps ...'
wget -c -O wps-office_11.1.0.8392_i386.deb "https://wdl1.cache.wps.cn/wps/download/ep/Linux2019/8392/wps-office_11.1.0.8392_i386.deb"
wget -c -O wps-office-fonts_1.0_all.deb http://kdl.cc.ksosoft.com/wps-community/download/fonts/wps-office-fonts_1.0_all.deb

echo '即将开始安装 wps ...'
apt -y install ./wps-office_11.1.0.8392_i386.deb ./wps-office-fonts_1.0_all.deb 

cd ..
