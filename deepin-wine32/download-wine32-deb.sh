#!/bin/bash
echo '在添加 deepin 安装源后，用该命令下载 wine32 所要的 deb 包'
cd `dirname $0`; pwd
apt-get download \
udis86 \
deepin-fonts-wine \
deepin-libwine \
deepin-wine32 \
deepin-wine32-preloader \
deepin-wine \
deepin-wine-binfmt \
deepin-wine-plugin \
deepin-wine-plugin-virtual \
deepin-wine-helper \
deepin-wine-uninstaller \
deepin-wine 
