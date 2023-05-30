#!/bin/bash
# License; Apache-2
# Originally from Raphael Moll
# Tested/Fixed for Android O by marc_soft@merlins.org 2017/12
# improved / completly reworked to play nice with Android 9 / 10 by anddisa@gmail.com 2019/12

# set path for busybox if wanted
if [[ "$1" == "--local" ]]; then
    CUSTOM_BUSYBOX_TARGET_BIN=/tmp/busybox
    shift;
fi
curr_dir="$(dirname "$0")"
. "$curr_dir/functions.sh"

set -e   # fail early

SYSTEM_PATTERN=""
if [[ "$1" == "--system-apps" ]]; then shift; SYSTEM_PATTERN="/system/app\|/system/priv-app\|/system/product/app\|/system/product/priv-app\|/product/overlay" ; fi

checkPrerequisites

updateBusybox

lookForAdbDevice

checkRootType

checkForCleanData

pushBusybox

mkBackupDir
pushd $DIR

PACKAGES=$($A shell "cmd package list packages -f")
echo $PACKAGES

stopRuntime

echo "## Pull apps"

DATADIR=""
DATA_PATTERN="/data/app"
PATTERN=$DATA_PATTERN
if [[ "$SYSTEM_PATTERN" != "" ]]; then PATTERN="$SYSTEM_PATTERN}\|$DATA_PATTERN" ; fi

for APP in `echo $PACKAGES | tr " " "\n" | grep "${PATTERN}"`; do
	echo $APP

	appPath=`echo $APP | sed 's/package://' | rev | cut -d "=" -f2- | rev`
	appDir=${appPath%/*}
	dataDir=`echo $APP | sed 's/package://' | rev | cut -d "=" -f1 | rev`

	echo $appPath
	echo $appDir
	echo $dataDir

        if [[ "$AS" == "$AROOT" ]]; then
#
# --- version for adb insecure
#
       		$AS "$BUSYBOX tar -cv -C $appDir . 2>/dev/null | gzip" | gzip -d | pv -trabi 1 | gzip -c9 > app_${dataDir}.tar.gz
       		$AS "$BUSYBOX tar -cv -C /data/data/$dataDir . 2>/dev/null | gzip" | gzip -d | pv -trabi 1 | gzip -c9 > data_${dataDir}.tar.gz
	else
#
# --- version for magisk rooted
#
		$AS "'cd $appDir && $BUSYBOX tar czf - ./' 2>/dev/null" | pv -trabi 1 > app_${dataDir}.tar.gz
		$AS "'cd /data/data/$dataDir && $BUSYBOX tar czf - ./' 2>/dev/null" | pv -trabi 1 > data_${dataDir}.tar.gz
	fi
done

cleanup

startRuntime
popd
