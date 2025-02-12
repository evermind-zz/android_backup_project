#!/bin/bash
# License; Apache-2
# Originally from Raphael Moll
# Tested/Fixed for Android O by marc_soft@merlins.org 2017/12
# improved / completly reworked to play nice with Android 9 / 10 by anddisa@gmail.com 2019/12

IS_LOCAL=false

DATA_PATH="/data"
SYSTEM_PATTERN="/system/app\|/system/priv-app\|/system/product/app\|/system/product/priv-app\|/product/overlay"
SINGLE_APP=""
DO_ONLY_MATCHING_APPS=false
MATCHING_APPS=""
DO_EXTRA_ACTION_EXT_DATA_SDCARD=false
DO_UPDATE_TOOLS=false
DO_ENCRYPT=false
DO_BACKUP_SYSTEM_APPS=false
DO_BACKUP_SYSTEM_APPS_ONLY=false
DO_LIST_APPS_ONLY=false
HAS_CUSTOM_BACKUP_DIR=false
USE_BUSYBOX_SELINUX_VARIANT=""

curr_dir="$(dirname "$0")"
. "$curr_dir/lib/functions_options.sh"

function displayHelp()
{
    echo
    echo "$0 is a script to backup apks, data, external data, keystores, permissions and external app related data from sdcard. For more information have a look at this help."
    echo
    for x in --backup-dir --data-path --debug --encrypt --ext-data-sdcard --local --matching-apps --no-apk --no-data --no-ext-data --no-keystore --no-perms --only-apk --only-data --only-ext-data --only-keystore --only-perms --single-app --system-apps --system-apps-only --update-tools --use-busybox-selinux --help --list-apps-only; do
        str="$(optionHelp "$x" true)"
        printPretty "$x" "$str"
    done
    echo ""
    echo "some examples:"
    echo "=========="
    echo "# create backup from local '/data' dump from single app:"
    echo "bash backup_apps.sh  --local --single-app org.videolan.vlc --data-path /path/to/datadump  --backup-dir myBackupDir"
    echo "=========="
    echo "# create backup from device matching appsingle app:"
    echo "bash backup_apps.sh --matching-apps \"com.starfinanz.mobile.android.dkbpushtan|com.github.bravenewpipe\""
    echo "=========="
    echo "# backup all user apks from device:"
    echo "bash  backup_apps.sh --backup-dir myBackupDir2 --no-keystore --no-data --no-ext-data --no-perms"
}

argCount=${#@}
while [ $argCount -gt 0 ] ; do
    if [[ "$1" == "--backup-dir" ]]; then
        HAS_CUSTOM_BACKUP_DIR=true
        shift; let argCount-=1
        BACKUP_DIR="$1"
        shift; let argCount-=1
    elif [[ "$1" == "--help" ]]; then
        shift; let argCount-=1
        displayHelp
        exit 0
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
    elif [[ "$1" == "--only-apk" ]]; then
        shift; let argCount-=1
        resetActions
        DO_ACTION_APK=true
    elif [[ "$1" == "--only-data" ]]; then
        shift; let argCount-=1
        resetActions
        DO_ACTION_DATA=true
    elif [[ "$1" == "--only-ext-data" ]]; then
        shift; let argCount-=1
        resetActions
        DO_ACTION_EXT_DATA=true
    elif [[ "$1" == "--only-keystore" ]]; then
        shift; let argCount-=1
        resetActions
        DO_ACTION_KEYSTORE=true
    elif [[ "$1" == "--only-perms" ]]; then
        shift; let argCount-=1
        resetActions
        DO_ACTION_PERMISSIONS=true
    elif [[ "$1" == "--ext-data-sdcard" ]]; then
        shift; let argCount-=1
        DO_EXTRA_ACTION_EXT_DATA_SDCARD=true
    elif [[ "$1" == "--update-tools" ]]; then
        shift; let argCount-=1
        DO_UPDATE_TOOLS=true
    elif [[ "$1" == "--data-path" ]]; then
        shift; let argCount-=1
        DATA_PATH=$1
        shift; let argCount-=1

    elif [[ "$1" == "--system-apps" ]]; then
        shift; let argCount-=1
        DO_BACKUP_SYSTEM_APPS=true
    elif [[ "$1" == "--system-apps-only" ]]; then
        shift; let argCount-=1
        DO_BACKUP_SYSTEM_APPS_ONLY=true
    elif [[ "$1" == "--list-apps-only" ]]; then
        shift; let argCount-=1
        DO_LIST_APPS_ONLY=true
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
            echo "-->eg. --matching-apps \"com.starfinanz.mobile.android.dkbpushtan|com.github.bravenewpipe\""
            exit 1
        fi
        MATCHING_APPS=$1
        shift; let argCount-=1
    else
        echo "ERROR unknown parameter: $1"
        exit
    fi
done

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

function backupPermsXmlData()
{
    local appSign="$1"
    local path="` echo "/runtime-permissions/pkg[@name='FOLLER']" | sed -e "s@FOLLER@$appSign@g"`"
    local result="`$AS cat "$DATA_PATH/system/users/0/runtime-permissions.xml" | xmlstarlet sel -t -c $path -n`"
    local permsFilename=$(getPermFileName "${appPackage}")

    # maybe some perms are stored for a shared user
    local path2="` echo "/runtime-permissions/shared-user[@name='FOLLER']" | sed -e "s@FOLLER@$appSign@g"`"
    local result2="`$AS cat "$DATA_PATH/system/users/0/runtime-permissions.xml" | xmlstarlet sel -t -c $path2 -n | sed -e 's@shared-user@pkg@g'`"
    local permsSharedFilename=$(getPermSharedUserFileName "${appPackage}")

    if [ "a${result}b" != "ab" ] ; then
        echo "$result" | encryptIfSelected > "$permsFilename"
    else
        einfo "[$appSign]: SKIP backup of app runtime-permissions -- as there are none"
    fi

    if [ "a${result2}b" != "ab" ] ; then
        echo "$result2" | encryptIfSelected > "$permsSharedFilename"
    else
        einfo "[$appSign]: SKIP backup of shared-user runtime-permissions -- as there are none"
    fi
}

function getGlobalMetaData()
{
    $AS cat "$DATA_PATH/system/packages.xml" | xmlstarlet sel -t   -c "/packages/version" -n \
        -c "/packages/permission-trees" -n -c "/packages/permissions" -n
}

function doesDirHaveFiles()
{
    local path="$1"
    if [ `$AS $BUSYBOX find "$path" ! -type d 2>/dev/null | wc -l` -eq 0 ] ; then
        return 1
    fi
    return 0
}

function determineToyboxBinary()
{
    local hasToybox=false
    for x in "toybox" "/data/local/toybox" "toybox-ext" "toybox_vendor" "toybox-stock" ; do
        if TOYBOX=$($AS which $x); then
            hasToybox=true
            break
        else
            continue
        fi
    done

    if $hasToybox ; then
        echo $TOYBOX
    fi
}

function preBackupActions()
{
    local package=$1
    local userid=$(getUserIdFromDumpsys "$package")
    noEmptyValueOrFail "$userid" "\$userid for the apk $package could not be read"
    local toybox=$(determineToyboxBinary) # for compatible ps version

    if [ "a${toybox}b" == "ab" ] ; then
        eerror "todo implement none toybox version -> process won't be stop"
        return 0
    fi
    local pids=$(
        (
            $AS $toybox ps -A -o PID -u $userid | tail -n +2
            $AS $toybox ls -l /proc/*/fd/* 2>/dev/null |
                grep -E "/data/data/|/media/" |
                grep -F /$package/ |
                cut -s -d / -f 3
        ) |
        sort -u -n | xargs | sed -e 's@ @,@g'
    )

    edebug "pids=$pids"

    STOPPED_PIDS=()
    if [[ -n $pids ]]; then
        while read -r user pid process; do
            if [[ $user    != u0_*                        ]]; then continue; fi
            if [[ $process == android.process.media       ]]; then continue; fi
            if [[ $process == com.android.externalstorage ]]; then continue; fi
            $AS $toybox kill -STOP $pid
            STOPPED_PIDS+=($pid)
            einfo "[$package] stopped PID $pid for uid $userid"
        done < <($AS $toybox ps -A -w -o USER,PID,NAME -p $pids)
    fi

    FNC_RETURN="${STOPPED_PIDS[*]}"
}

function postBackupActions()
{
    local package="$1"
    local stoppedPids=$2
    local toybox=$(determineToyboxBinary) # for compatible ps version

    if [[ -n $stoppedPids ]]; then
        for pid in ${stoppedPids[@]} ; do
            local hasProcessWithPid=`$AS $toybox ps -A  -p "${pid}" | tail -n +2 | wc -l`
            if [ $hasProcessWithPid -eq 1 ] ; then
                einfo "[$package] continue PID $pid"
                $AS $toybox kill -CONT "${pid}"
            fi
        done
    fi
}
## END functions

checkPrerequisites

updateBusybox "$DO_UPDATE_TOOLS"
updateTarBinary "$DO_UPDATE_TOOLS"

if $IS_LOCAL ; then
    PACKAGES=$($AS cat "$DATA_PATH/system/packages.xml" | xmlstarlet sel -T -t -m "//packages/package"  -v "@codePath" -o "|" -v "@name" -n)
else
    lookForAdbDevice

    checkRootType

    #checkForCleanData
    PACKAGES=$($A shell "cmd package list packages -f")

    if ! $HAS_CUSTOM_BACKUP_DIR ; then
        einfo2 mkBackupDir
        mkBackupDir
    fi
fi

edebug "$PACKAGES"


DATA_PATTERN="/data/app"
PATTERN=$DATA_PATTERN
if $DO_BACKUP_SYSTEM_APPS; then
    PATTERN="${SYSTEM_PATTERN}\|$DATA_PATTERN"
fi
if $DO_BACKUP_SYSTEM_APPS_ONLY; then
    PATTERN="${SYSTEM_PATTERN}"
fi

if $DO_ENCRYPT ; then
    checkIfPwPresent true
fi

matchApp
APPS="$FNC_RETURN"
edebug "APPS=$APPS"

if [ ${#APPS} -gt 0 ] ; then
    pushBusybox "$USE_BUSYBOX_SELINUX_VARIANT"
    pushTarBinary
fi


noEmptyValueOrFail "$BACKUP_DIR" "backup dir can not be empty. On --local always specify --backup-dir too"
mkdir -p "$BACKUP_DIR"
pushd "$BACKUP_DIR" &> /dev/null

globalmetadataFile=$(getGlobalMetaDataFileName)
if ! test -e ${globalmetadataFile} && ! test -e ${globalmetadataFile/${g_encExt}/} ; then
    echo "<packages>`getGlobalMetaData`</packages>" | encryptIfSelected > $(getGlobalMetaDataFileName)
fi

showGlobalBackupInfo

einfo "## Pull apps"
for APP in $APPS; do
    if $IS_LOCAL ; then
       appDir="$(echo $APP | awk -F'|' '{print $1}' | sed 's@/data@@')"
       dataDir="$(echo $APP | awk -F'|' '{print $2}')"
    else
        appPath=`echo $APP | sed 's/package://' | rev | cut -d "=" -f2- | rev`
        appDir=${appPath%/*}
        dataDir=`echo $APP | sed 's/package://' | rev | cut -d "=" -f1 | rev`

        # stop app process(es) for backup
        if ! $DO_LIST_APPS_ONLY ; then
            preBackupActions "$dataDir"
            stoppedPids="$FNC_RETURN"
        fi
    fi

    if $DO_LIST_APPS_ONLY ; then
        einfo "APP|$dataDir"
        continue
    else
        echo "APP:$APP"
    fi

    stoppedPids=""
    if ! $IS_LOCAL ; then
        # stop app process(es) for backup
        preBackupActions "$dataDir"
        stoppedPids="$FNC_RETURN"
    fi

    edebug appPath=$appPath
    edebug appDir=$appDir
    edebug dataDir=$dataDir

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
        appDir=${appDir/\/data\//} # strip the data mount point here
        einfo "[$appSign]: backup apk(s): $APP "
        $AS $TAR -C $DATA_PATH/${appDir} -cpf - ./ 2>/dev/null | compressor | pv -trabi 1 | encryptIfSelected > "$appPackage"
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
        USERID="`getUserIdOfFile  $DATA_PATH/data/$dataDir`"
        keystorePath=$DATA_PATH/misc/keystore/user_0
        keystoreForAppList=/tmp/filelist.backup_apps.list

        $AS $BUSYBOX find "$keystorePath" -name "*${USERID}_*" | sed "s@${keystorePath}/@@g" > $keystoreForAppList
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
    if $DO_EXTRA_ACTION_EXT_DATA_SDCARD ; then
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
        backupPermsXmlData "$dataDir" "$appPackage"
    fi

    ############
    # backup meta data
    getMetaXmlData "$dataDir" | encryptIfSelected > $(getMetaFileName "${appPackage}")


    if ! $IS_LOCAL ; then
        postBackupActions "$appSign" "$stoppedPids"
    fi
done

cleanup

popd # -> $BACKUP_DIR
