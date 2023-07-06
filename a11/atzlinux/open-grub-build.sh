chmod -v 755 pool/main/g/grub2
chmod -v 755 pool/main/g/grub-efi-a*

./udeb.sh

apt-ftparchive generate -c apt-ftparchive-atz11.conf main-aptgenerate-atz11.conf

./mk-Release-v11.sh
