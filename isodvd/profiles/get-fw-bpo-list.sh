#/bin/sh
cp -v firmware-bpo12.pkg.list firmware-bpo12.pkg.list.backup
for i in `cat firmware.pkg.list`
do
echo $i
rmadison $i|grep bpo12
B=`echo $?`
echo $B
	if [ $B == 0 ] ;then
	echo $i >> firmware-bpo12.pkg.list
	fi
done
