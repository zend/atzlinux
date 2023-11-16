#!/bin/bash
echo "开始卸载 atzlinux 常用中文软件 ..."

apt -y purge  \
baidunetdisk \
sogoupinyin \
electronic-wechat \
wps-office wps-office-fonts

apt -y purge app.web.youdao.dict

apt -y purge linuxqq

apt -y purge fonts-zh-cn-misc-atzlinux

apt -y purge atzlinux-store-v12
apt -y purge atzlinux-v12-archive-keyring

echo "开始卸载不需要使用的中文软件依赖包 ..."
apt -y autoremove
echo "卸载完成,谢谢使用《铜豌豆 Linux》！"
echo "欢迎您在有需要的时候，再次使用《铜豌豆 Linux》https://www.atzlinux.com"
