#!/bin/sh

for k in `cat signed.key.list`
do

wget "http://keyserver.ubuntu.com/pks/lookup?op=get&options=mr&search=$k" -O $k.asc

done
