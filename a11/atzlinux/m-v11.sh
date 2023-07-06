rm -v nohup.out
chmod -v 000 pool/main/g/grub2
chmod -v 000 pool/main/g/grub-efi-a*

apt-ftparchive generate -c apt-ftparchive-atz11.conf contrib-aptgenerate-atz11.conf 
apt-ftparchive generate -c apt-ftparchive-atz11.conf main-aptgenerate-atz11.conf
apt-ftparchive generate -c apt-ftparchive-atz11.conf non-free-aptgenerate-atz11.conf
apt-ftparchive generate -c apt-ftparchive-atz11.conf non-free-firmware-aptgenerate-atz11.conf
./mk-Release-v11.sh 
