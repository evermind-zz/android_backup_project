#!/bin/bash
# License; Apache-2
# Originally from Raphael Moll
# Tested/Fixed for Android O by marc_soft@merlins.org 2017/12
# improved / completly reworked to play nice with Android 9 / 10 by anddisa@gmail.com 2019/12

# set path for busybox if wanted
IS_LOCAL=false

DATA_PATH="/data"
SYSTEM_PATTERN=""
SINGLE_APP=""
DO_ONLY_MATCHING_APPS=false
MATCHING_APPS=""
DO_BACKUP_EXTRA_DATA=false

argCount=${#@}
while [ $argCount -gt 0 ] ; do
    if [[ "$1" == "--local" ]]; then
        IS_LOCAL=true
        CUSTOM_BUSYBOX_TARGET_BIN=/tmp/busybox
        shift; let argCount-=1

    elif [[ "$1" == "--data-path" ]]; then
        IS_LOCAL=true
        #CUSTOM_BUSYBOX_TARGET_BIN=/tmp/busybox
        shift; let argCount-=1
        DATA_PATH=$1
        shift; let argCount-=1

    elif [[ "$1" == "--system-apps" ]]; then
        shift; let argCount-=1
        SYSTEM_PATTERN="/system/app\|/system/priv-app\|/system/product/app\|/system/product/priv-app\|/product/overlay"

    elif [[ "$1" == "--single-app" ]]; then
        shift; let argCount-=1
        if [ "a${1}b" == "ab" ] ; then
            echo "ERROR: You have to specify a package signature for --single-app"
            echo "-->eg. --single-app com.starfinanz.mobile.android.dkbpushtan"
            exit 1
        fi
        SINGLE_APP=$1
        shift; let argCount-=1

    elif [[ "$1" == "--matching-apps" ]]; then
        DO_ONLY_MATCHING_APPS=true
        shift; let argCount-=1
        if [ "a${1}b" == "ab" ] ; then
            echo "ERROR: You have to specify a package signature(s) for --matching-apps"
            echo "-->eg. --matching-apps com.starfinanz.mobile.android.dkbpushtan|com.github.bravenewpipe"
            exit 1
        fi
        MATCHING_APPS=$1
        shift; let argCount-=1

    elif [[ "$1" == "--extra-data" ]]; then
        DO_BACKUP_EXTRA_DATA=true
        shift; let argCount-=1
    else
        echo "ERROR unknown parameter: $1"
        exit
    fi
done

echo $DATA_PATH

if $IS_LOCAL ; then
    echo islocal
else
    echo not local
fi

curr_dir="$(dirname "$0")"
. "$curr_dir/functions.sh"

set -e   # fail early


#checkPrerequisites

updateBusybox

#lookForAdbDevice

#checkRootType

#checkForCleanData

#pushBusybox

#mkBackupDir
DIR=test
mkdir -p $DIR
pushd $DIR

if $IS_LOCAL ; then
    PACKAGES=$(xmlstarlet select -T -t -m "//packages/package"  -v "@codePath" -o "|" -v "@name" -n $DATA_PATH/system/packages.xml)
else
    PACKAGES=$($A shell "cmd package list packages -f")
fi
#echo $PACKAGES

#stopRuntime

echo "## Pull apps"

function matchApp()
{
    if $DO_ONLY_MATCHING_APPS ; then
        echo $PACKAGES | tr " " "\n" | egrep "($MATCHING_APPS)$"
    else
        echo $PACKAGES | tr " " "\n" | grep "${PATTERN}" | grep "$SINGLE_APP"
    fi
}

DATADIR=""
DATA_PATTERN="/data/app"
PATTERN=$DATA_PATTERN
if [[ "$SYSTEM_PATTERN" != "" ]]; then PATTERN="$SYSTEM_PATTERN}\|$DATA_PATTERN" ; fi

for APP in `matchApp`; do
	echo $APP

        if $IS_LOCAL ; then
           appDir="$(echo $APP | awk -F'|' '{print $1}' | sed 's@/data@@')"
           dataDir="$(echo $APP | awk -F'|' '{print $2}')"
        else
	    appPath=`echo $APP | sed 's/package://' | rev | cut -d "=" -f2- | rev`
	    appDir=${appPath%/*}
	    dataDir=`echo $APP | sed 's/package://' | rev | cut -d "=" -f1 | rev`
        fi

	echo $appPath
	echo $appDir
	echo $dataDir

        if $IS_LOCAL ; then
                # get apk
		sudo $BUSYBOX tar -C $DATA_PATH/$appDir -czpf - ./ 2>/dev/null | pv -trabi 1 > app_${dataDir}.tar.gz
                # get data
		sudo $BUSYBOX tar -C $DATA_PATH/data/$dataDir -czpf - ./ 2>/dev/null | pv -trabi 1 > data_${dataDir}.tar.gz

                # get keystore if exists
                AS=""
                USERID="`getUserId  $DATA_PATH/data/$dataDir`"
                keystorePath=$DATA_PATH/misc/keystore/user_0
                keystoreForAppList=/tmp/filelist.backup_apps.list
                olddir="$PWD"
                #cd $keystorePath && $BUSYBOX find | grep "${USERID}_" > $keystoreForAppList
                cd $keystorePath && sudo $BUSYBOX find -name "*${USERID}_*" > $keystoreForAppList
                cd "$olddir" &>/dev/null
                # check if there are any $USERID matches at all
                if [ `$BUSYBOX stat -c %s $keystoreForAppList` -gt 0 ] ; then
                    sudo $BUSYBOX tar -C $keystorePath -czpf - -T "$keystoreForAppList" 2>/dev/null | pv -trabi 1 > keystore_${dataDir}.tar.gz
                fi
                rm $keystoreForAppList

                if $DO_BACKUP_EXTRA_DATA ; then
                    extraDataPath="$DATA_PATH/media/0/Android/data/${dataDir}"
		    sudo $BUSYBOX tar -C $extraDataPath -czpf - ./ 2>/dev/null | pv -trabi 1 > extradata_${dataDir}.tar.gz
                fi


        elif [[ "$AS" == "$AROOT" ]]; then
#
# --- version for adb insecure
#
       		echo "$AS "$BUSYBOX tar -cv -C $appDir . 2>/dev/null | gzip" | gzip -d | pv -trabi 1 | gzip -c9 > app_${dataDir}.tar.gz"
       		echo "$AS "$BUSYBOX tar -cv -C $DATA_PATH/data/$dataDir . 2>/dev/null | gzip" | gzip -d | pv -trabi 1 | gzip -c9 > data_${dataDir}.tar.gz"
	else
#
# --- version for magisk rooted
#
		echo $AS "'cd $appDir && $BUSYBOX tar czf - ./' 2>/dev/null" | pv -trabi 1 > app_${dataDir}.tar.gz
		echo $AS "'cd $DATA_PATH/data/$dataDir && $BUSYBOX tar czf - ./' 2>/dev/null" | pv -trabi 1 > data_${dataDir}.tar.gz

                echo appDir=$appDir appTar=app_${dataDir}.tar.gz
                echo appData=$DATA_PATH/data/$dataDir dataTar= data_${dataDir}.tar.gz
                USERID="`getUserId  $DATA_PATH/data/$dataDir`"
                echo $USERID
	fi
done

#cleanup

#startRuntime
popd
