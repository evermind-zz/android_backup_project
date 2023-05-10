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
DO_IT=true # for try run
DO_ACTION_APK=true
DO_ACTION_DATA=true
DO_ACTION_EXT_DATA=true
DO_ACTION_KEYSTORE=true
DO_ACTION_PERMISSIONS=true
HAS_CUSTOM_BACKUP_DIR=false

argCount=${#@}
while [ $argCount -gt 0 ] ; do
    if [[ "$1" == "--backup-dir" ]]; then
        HAS_CUSTOM_BACKUP_DIR=true
        shift; let argCount-=1
        BACKUP_DIR="$1"
        shift; let argCount-=1
    elif [[ "$1" == "--local" ]]; then
        IS_LOCAL=true
        CUSTOM_BUSYBOX_TARGET_BIN=/tmp/busybox
        shift; let argCount-=1
    elif [[ "$1" == "--do-nothing" ]]; then
        shift; let argCount-=1
        DO_IT=false
    elif [[ "$1" == "--no-apk" ]]; then
        shift; let argCount-=1
        DO_ACTION_APK=false
    elif [[ "$1" == "--no-data" ]]; then
        shift; let argCount-=1
        DO_ACTION_DATA=false
    elif [[ "$1" == "--no-ext-data" ]]; then
        shift; let argCount-=1
        DO_ACTION_EXT_DATA=false
    elif [[ "$1" == "--no-keystore" ]]; then
        shift; let argCount-=1
        DO_ACTION_KEYSTORE=false
    elif [[ "$1" == "--no-perms" ]]; then
        shift; let argCount-=1
        DO_ACTION_PERMISSIONS=false
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

if ! $HAS_CUSTOM_BACKUP_DIR ; then
    einfo2 mkBackupDir
    #mkBackupDir
fi
mkdir -p $BACKUP_DIR
pushd $BACKUP_DIR

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
        NEW_APPS=()
        for x in `echo $MATCHING_APPS | sed -e 's@|@ @g'` ; do
            NEW_APPS+=(`echo "${PACKAGES}" | grep "${x}$"`)
        done
        #echo $PACKAGES | tr " " "\n" | egrep "($MATCHING_APPS)$"
        PACKAGES="${NEW_APPS[*]}"
        echo $PACKAGES
    else
        echo $PACKAGES | tr " " "\n" | grep "${PATTERN}" | grep "$SINGLE_APP"
    fi
}

function getPermsXmlData()
{
    local appSign="$1"
    sudo xmlstarlet sel -t -c "` echo "/runtime-permissions/pkg[@name = 'FOLLER']" | sed -e "s@FOLLER@$appSign@g"`" $DATA_PATH/system/users/0/runtime-permissions.xml
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
                mkdir "${dataDir}" # dir per app
                appPackage="$(getAppFileName "${dataDir}")"
                # get apk
                if $DO_ACTION_APK ; then
		    sudo $BUSYBOX tar -C $DATA_PATH/$appDir -czpf - ./ 2>/dev/null | pv -trabi 1 > "$appPackage"
                fi
                # get data
                if $DO_ACTION_DATA ; then
		    sudo $BUSYBOX tar -C $DATA_PATH/data/$dataDir -czpf - ./ 2>/dev/null | pv -trabi 1 > "$(getDataFileName "${appPackage}")"
                fi

                if $DO_ACTION_KEYSTORE ; then
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
                        sudo $BUSYBOX tar -C $keystorePath -czpf - -T "$keystoreForAppList" 2>/dev/null | pv -trabi 1 > "$(getKeystoreFileName "${appPackage}")"
                    fi
                    rm $keystoreForAppList
                fi

                if $DO_ACTION_EXT_DATA ; then
                    extraDataPath="$DATA_PATH/media/0/Android/data/${dataDir}"
		    sudo $BUSYBOX tar -C $extraDataPath -czpf - ./ 2>/dev/null | pv -trabi 1 > "$(getExtraDataFileName "${appPackage}")"
                fi

                if $DO_ACTION_PERMISSIONS ; then
                    getPermsXmlData "$dataDir" > $(getPermFileName "${appPackage}")
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
