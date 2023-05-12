#!/bin/bash
# License; Apache-2
# Originally from Raphael Moll
# Tested/Fixed for Android O by marc_soft@merlins.org 2017/12
# improved / completly reworked to play nice with Android 9 / 10 by anddisa@gmail.com 2019/12

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
DO_ACTION_EXT_DATA_SDCARD=false
DO_UPDATE_TOOLS=false
DO_ENCRYPT=false
HAS_CUSTOM_BACKUP_DIR=false
USE_BUSYBOX_SELINUX_VARIANT=""

argCount=${#@}
while [ $argCount -gt 0 ] ; do
    if [[ "$1" == "--backup-dir" ]]; then
        HAS_CUSTOM_BACKUP_DIR=true
        shift; let argCount-=1
        BACKUP_DIR="$1"
        shift; let argCount-=1
    elif [[ "$1" == "--debug" ]]; then
        shift; let argCount-=1
        DEBUG=true
    elif [[ "$1" == "--encrypt" ]]; then
        shift; let argCount-=1
        DO_ENCRYPT=true
    elif [[ "$1" == "--local" ]]; then
        IS_LOCAL=true
        AS=sudo
        CUSTOM_BUSYBOX_TARGET_BIN=/tmp/busybox
        CUSTOM_TAR_TARGET_BIN=/tmp/tar
        shift; let argCount-=1
    elif [[ "$1" == "--use-busybox-selinux" ]]; then
        shift; let argCount-=1
        USE_BUSYBOX_SELINUX_VARIANT="Yeah"
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
    elif [[ "$1" == "--ext-data-sdcard" ]]; then
        shift; let argCount-=1
        DO_ACTION_EXT_DATA_SDCARD=true
    elif [[ "$1" == "--update-tools" ]]; then
        shift; let argCount-=1
        DO_UPDATE_TOOLS=true
    elif [[ "$1" == "--data-path" ]]; then
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

## BEGIN functions
function getMetaXmlData()
{
    local appSign="$1"
    $AS cat $DATA_PATH/system/packages.xml | xmlstarlet sel -t -c "` echo "/packages/package[@name = 'FOLLER']" | sed -e "s@FOLLER@$appSign@g"`"
}

function matchApp()
{
    if $DO_ONLY_MATCHING_APPS ; then
        NEW_APPS=()
        for x in `echo $MATCHING_APPS | sed -e 's@|@ @g'` ; do
            NEW_APPS+=(`echo "${PACKAGES}" | grep "${x}$"`)
        done
        #echo $PACKAGES | tr " " "\n" | egrep "($MATCHING_APPS)$"
        PACKAGES="${NEW_APPS[*]}"
        FNC_RETURN=$PACKAGES
    else
        FNC_RETURN=$(echo $PACKAGES | tr " " "\n" | grep "${PATTERN}" | grep "$SINGLE_APP")
    fi
}

function getPermsXmlData()
{
    local appSign="$1"
    $AS cat "$DATA_PATH/system/users/0/runtime-permissions.xml" | xmlstarlet sel -t -c \
        "` echo "/runtime-permissions/pkg[@name = 'FOLLER']" | sed -e "s@FOLLER@$appSign@g"`"
}

function getGlobalMetaData()
{
    $AS cat "$DATA_PATH/system/packages.xml" | xmlstarlet sel -t   -c "/packages/version" -n \
        -c "/packages/permission-trees" -n -c "/packages/permissions" -n
}

function doesDirHaveFiles()
{
    local path="$1"
    if [ `find "$path" ! -type d 2>/dev/null | wc -l` -eq 0 ] ; then
        return 1
    fi
    return 0
}
## END functions

#checkPrerequisites

updateBusybox "$DO_UPDATE_TOOLS"
updateTarBinary "$DO_UPDATE_TOOLS"

if ! $HAS_CUSTOM_BACKUP_DIR ; then
    einfo2 mkBackupDir
    #mkBackupDir
fi

if $IS_LOCAL ; then
    PACKAGES=$($AS cat "$DATA_PATH/system/packages.xml" | xmlstarlet sel -T -t -m "//packages/package"  -v "@codePath" -o "|" -v "@name" -n)
else
    lookForAdbDevice

    checkRootType

    #checkForCleanData
    PACKAGES=$($A shell "cmd package list packages -f")
fi

edebug "$PACKAGES"


DATA_PATTERN="/data/app"
PATTERN=$DATA_PATTERN
if [[ "$SYSTEM_PATTERN" != "" ]]; then PATTERN="$SYSTEM_PATTERN}\|$DATA_PATTERN" ; fi

if $DO_ENCRYPT ; then
    checkIfPwPresent true
fi

globalmetadataFile=$(getGlobalMetaDataFileName)
if ! test -e ${globalmetadataFile} && ! test -e ${globalmetadataFile/${g_encExt}/} ; then
    echo "<packages>`getGlobalMetaData`</packages>" | encryptIfSelected > $(getGlobalMetaDataFileName)
fi

showGlobalBackupInfo

matchApp
APPS="$FNC_RETURN"
edebug "APPS=$APPS"

if [ ${#APPS} -gt 0 ] ; then
    pushBusybox "$USE_BUSYBOX_SELINUX_VARIANT"
    pushTarBinary
fi

if ! $IS_LOCAL ; then
    #stopRuntime
    echo -n
fi

mkdir -p "$BACKUP_DIR"
pushd "$BACKUP_DIR" &> /dev/null

einfo "## Pull apps"
for APP in $APPS; do
	echo $APP

        if $IS_LOCAL ; then
           appDir="$(echo $APP | awk -F'|' '{print $1}' | sed 's@/data@@')"
           dataDir="$(echo $APP | awk -F'|' '{print $2}')"
        else
	    appPath=`echo $APP | sed 's/package://' | rev | cut -d "=" -f2- | rev`
	    appDir=${appPath%/*}
	    dataDir=`echo $APP | sed 's/package://' | rev | cut -d "=" -f1 | rev`
        fi

	edebug appPath=$appPath
	edebug appDir=$appDir
	edebug dataDir=$dataDir

        if $IS_LOCAL ; then
                appSign="${dataDir}"
                if ! test -e "${dataDir}" ; then
                    mkdir "${dataDir}" # dir per app
                else
                    einfo "[$appSign]: SKIP backup -- a backup already exists in $BACKUP_DIR"
                    continue
                fi
                appPackage="$(getAppFileName "${dataDir}")"

                #####################
                # backup app
                #####################
                if $DO_ACTION_APK ; then
                    einfo "[$appSign]: backup apk(s): $APP "
		    $AS $TAR -C $DATA_PATH/$appDir -cpf - ./ 2>/dev/null | compressor | pv -trabi 1 | encryptIfSelected > "$appPackage"
                else
                    einfo "[$appSign]: SKIP backup apk(s) -- as requested via commandline"
                fi

                #####################
                # backup app data
                #####################
                if $DO_ACTION_DATA ; then
                    einfo "[$appSign]: backup app data"
		    $AS $TAR -C $DATA_PATH/data/$dataDir -cpf - ./ 2>/dev/null | compressor | pv -trabi 1 | encryptIfSelected > "$(getDataFileName "${appPackage}")"
                else
                    einfo "[$appSign]: SKIP backup app data -- as requested via commandline"
                fi

                #####################
                # backup keystore(s)
                #####################
                if $DO_ACTION_KEYSTORE ; then
                    # get keystore if exists
                    USERID="`getUserId  $DATA_PATH/data/$dataDir`"
                    keystorePath=$DATA_PATH/misc/keystore/user_0
                    keystoreForAppList=/tmp/filelist.backup_apps.list

                    $AS "$BUSYBOX find "$keystorePath" -name "*${USERID}_*"" | sed "s@${keystorePath}/@@g" > $keystoreForAppList
                    noOfKeystores=`stat -c %s $keystoreForAppList`
                    if [ $noOfKeystores -gt 0 ] ; then
                        einfo "[$appSign]: backup keystores"
                        cat "$keystoreForAppList" | $AS $TAR -C "$keystorePath" --verbatim-files-from -T- -cpf - 2>/dev/null | gzip | pv -trabi 1 | encryptIfSelected > "$(getKeystoreFileName "${appPackage}")"
                    else
                        einfo "[$appSign]: SKIP backup keystores -- no keystores for this app"
                    fi
                    rm $keystoreForAppList
                else
                    einfo "[$appSign]: SKIP backup keystores -- as requested via commandline"
                fi

                #####################
                # backup app extra data
                #####################
                if $DO_ACTION_EXT_DATA ; then
                    extraDataPath="$DATA_PATH/media/0/Android/data/${dataDir}"
                    if doesDirHaveFiles "$extraDataPath" ; then
                        einfo "[$appSign]: backup app extra data"
		        $AS $TAR -C $extraDataPath -cpf - ./ 2>/dev/null | compressor | pv -trabi 1 | encryptIfSelected > "$(getExtraDataFileName "${appPackage}")"
                    else
                        einfo "[$appSign]: NOT backup app extra data -- no files to backup"
                    fi
                else
                    einfo "[$appSign]: SKIP backup app extra data -- as requested via commandline"
                fi

                ## at the moment this is not working on local
                if $DO_ACTION_EXT_DATA_SDCARD ; then
                    for sdcardExtraData in $($AS 'ls -d /mnt/media_rw/*') ; do

                        extraDataPath="$sdcardExtraData/Android/data/${dataDir}"
                        if doesDirHaveFiles "$extraDataPath" ; then
                            sdcardId="$(basename "$sdcardExtraData")"
                            extraDataFileName="$(getExtraDataFileName "${appPackage}" | sed -e "s@\(.tar.gz\)@${sdcardId}\1@g")"
		            $AS $TAR -C $extraDataPath -cpf - ./ 2>/dev/null | compressor | pv -trabi 1 | encryptIfSelected > "$extraDataFileName"
                        fi
                    done
                fi

                if $DO_ACTION_PERMISSIONS ; then
                    getPermsXmlData "$dataDir" | encryptIfSelected > $(getPermFileName "${appPackage}")
                fi

                ############
                # backup meta data
                getMetaXmlData "$dataDir" | encryptIfSelected > $(getMetaFileName "${appPackage}")



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

cleanup

if ! $IS_LOCAL ; then
    #startRuntime
    echo -n
fi
popd &> /dev/null # -> $BACKUP_DIR
