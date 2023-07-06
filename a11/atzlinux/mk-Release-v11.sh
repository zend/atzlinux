apt-ftparchive -c apt-ftparchive-atz11.conf release dists/bullseye/ > dists/bullseye/Release
if [ -f dists/bullseye/InRelease.old ]; then
	rm -fv dists/bullseye/InRelease.old
fi
if [ -f dists/bullseye/InRelease ]; then
	mv dists/bullseye/InRelease dists/bullseye/InRelease.old
fi
gpg -u 0x4EE54C28 -o dists/bullseye/InRelease --clear-sign dists/bullseye/Release
