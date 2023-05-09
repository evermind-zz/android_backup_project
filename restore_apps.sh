#!/bin/bash
# License; Apache-2
# Originally from Raphael Moll
# Tested/Fixed for Android O by marc_soft@merlins.org 2017/12
# improved / completly reworked to play nice with Android 9 / 10 by anddisa@gmail.com 2019/12

cat <<EOF
WARNING: restoring random system apps is quite likely to make things worse
unless you are copying between 2 identical devices.
You probably want to mv backupdir/app_{com.android,com.google}* /backup/location
This will cause this script not to try and restore system app data

EOF
#sleep 5

# variables could be set via commandline args
DATA_PATH="/data"
BACKUP_DIR=""
DO_SINGLE_APP=false
SINGLE_APP=""
DO_ONLY_MATCHING_APPS=false
MATCHING_APPS=""

argCount=${#@}
while [ $argCount -gt 0 ] ; do

    if [[ "$1" == "--backup-dir" ]]; then
        shift; let argCount-=1
        BACKUP_DIR="$1"
        shift; let argCount-=1

    elif [[ "$1" == "--data-path" ]]; then
        #CUSTOM_BUSYBOX_TARGET_BIN=/tmp/busybox
        shift; let argCount-=1
        DATA_PATH=$1
        shift; let argCount-=1
    elif [[ "$1" == "--single-app" ]]; then
        shift; let argCount-=1
        if [ "a${1}b" == "ab" ] ; then
            echo "ERROR: You have to specify a package signature for --single-app"
            echo "-->eg. --single-app com.starfinanz.mobile.android.dkbpushtan"
            exit 1
        fi
        DO_SINGLE_APP=true
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

    else
        echo "ERROR unknown parameter: $1"
        exit
    fi
done

if [[ ! -d "$BACKUP_DIR" ]] || [ "a${BACKUP_DIR}b" == "ab" ]; then
	echo "Usage: $0 --backup-dir <data-dir>"
	echo "Must be created with ./backup_apps.sh"
	exit 2
fi

curr_dir="$(dirname "$0")"
. "$curr_dir/functions.sh"

set -e   # fail early

OLDIFS="$IFS"

checkPrerequisites

updateBusybox
updateTar

lookForAdbDevice

checkRootType

pushBusybox
pushTarBinary

cd "$BACKUP_DIR"

APPS=$(ls app_*.tar.gz)

function matchApp() {
    if $DO_ONLY_MATCHING_APPS ; then
        FNC_RETURN="`echo "$APPS" | egrep "app_($MATCHING_APPS).tar.gz"`"
	echo "## Push matching app(s) in $BACKUP_DIR: "${FNC_RETURN}""
    elif $DO_SINGLE_APP ; then
        FNC_RETURN="`echo "$APPS" | grep "app_$SINGLE_APP.tar.gz"`"
	echo "## Push single app in $BACKUP_DIR: "${FNC_RETURN}""
    else
        FNC_RETURN="`echo "$APPS"`"
	echo "## Push all apps in $BACKUP_DIR: "${FNC_RETURN}""
    fi
}

function createDataPermUpdateScript() {
    local workDir="$1"
    local oldGid="$2"
    local newGid="$3"
    local oldUid="$4"
    local newUid="$5"
    local oldGidVar=$(($oldGid + 10000))
    local newGidVar=$(($newGid + 10000))

    echo "# dataDir: oldGid=$oldGid newGid=$newGid oldUid=$oldUid newUid=$newUid oldGidVar=$oldGidVar newGidVar=$newGidVar"

    eval $AS "$BUSYBOX find $workDir ! -type l -exec $BUSYBOX stat -c \"chownPATTERNOLDU=%u:OLDG=%gPATTERNBEGINrogaPATTERN%nPATTERNENDrogaPATTERN\" {} +" \
    | while read line ; do
        line="`echo "$line" | sed -e 's@PATTERN@ @g' -e 's@\"@\\\\"@g' -e 's@BEGINroga @"@g' -e 's@ ENDroga @"@g'`"
        echo "oldOwner $line" | sed -e 's@OLDU=@@g' -e 's@OLDG=@@g' | sed 's@^@# @'
        OLDU=`echo "$line" | egrep -o 'OLDU=[^:]*' | sed -e 's@OLDU=@@g'`
        OLDG=`echo "$line" | egrep -o 'OLDG=[^ ]*' | sed -e 's@OLDG=@@g'`
        edebug "OLDU=$OLDU OLDG=$OLDG"

        # replace gid
        if [ "$OLDG" -ne "$oldGid" ] ; then
            # test if we have special GidVar
            if [ "$OLDG" -eq "$oldGidVar" ] ; then
                # replace $oldGidVar with newGidVar
                line="`echo "$line" | sed "s@OLDG=$oldGidVar@$newGidVar@g"`"
                #echo "$OLDG" -eq "$oldGidVar"
            elif [ "$OLDG" -eq "0" ] ; then # keep do nothing eg lib dir is root only
                line="`echo "$line" | sed "s@OLDG=0@0@g"`"
            else
                echo GIDERROR $line
                exit 1
            fi
        else
            line="`echo "$line" | sed "s@OLDG=$oldGid@$newGid@g"`"
        fi

        # replace uid
        if [ "$OLDU" -eq "$oldUid" ] ; then
            line="`echo "$line" | sed "s@OLDU=$oldUid@$newUid@g"`"
        elif [ "$OLDG" -eq "0" ] ; then # keep do nothing eg lib dir is root only
            line="`echo "$line" | sed "s@OLDU=0@0@g"`"
        else
            echo UIDERROR $line
            exit 1
        fi

        echo $line
    done
}

function createExtDataPermUpdateScript() {
    local workDir="$1"
    local oldGid="$2"
    local newGid="$3"
    local oldGidVar=$(($oldGid + 20000))
    local newGidVar=$(($newGid + 20000))
    local media_rw=1023

    echo "# extDataDir: oldGid=$oldGid newGid=$newGid oldGidVar=$oldGidVar newGidVar=$newGidVar"

    eval $AS "$BUSYBOX find $workDir ! -type l -exec $BUSYBOX stat -c \"chownPATTERNOLDU=%u:OLDG=%gPATTERNBEGINrogaPATTERN%nPATTERNENDrogaPATTERN\" {} +" \
    | while read line ; do
        line="`echo "$line" | sed -e 's@PATTERN@ @g' -e 's@\"@\\\\"@g' -e 's@BEGINroga @"@g' -e 's@ ENDroga @"@g'`"
        echo "oldOwner $line" | sed -e 's@OLDU=@@g' -e 's@OLDG=@@g' | sed 's@^@# @'
        OLDU=`echo "$line" | egrep -o 'OLDU=[^:]*' | sed -e 's@OLDU=@@g'`
        OLDG=`echo "$line" | egrep -o 'OLDG=[^ ]*' | sed -e 's@OLDG=@@g'`
        edebug "OLDU=$OLDU OLDG=$OLDG"

        # replace gid
        if [ "$OLDG" -ne "$media_rw" ] ; then
            # test if we have special GidVar
            if [ "$OLDG" -eq "$oldGidVar" ] ; then
                # replace $oldGidVar with newGidVar
                line="`echo "$line" | sed "s@OLDG=$oldGidVar@$newGidVar@g"`"
                #echo "$OLDG" -eq "$oldGidVar"
            else
                echo GIDERROR $line
                exit 1
            fi
        else
            line="# skip as same perms `echo "$line" | sed "s@OLDG=$media_rw@$media_rw@g"`"
        fi

        # no need to replace uid as it should be $media_rw
        # -> just prepare $line executable
        if [ "$OLDU" -eq "$media_rw" ] ; then
            line="`echo "$line" | sed "s@OLDU=$media_rw@$media_rw@g"`"
        else
            echo UIDERROR $line
            exit 1
        fi

        echo $line
    done
}

function restoreKeystore() {
    local keystoreTmpDir="$1"
    local oldUid="$2"
    local newUid="$3"
    local keystorePath="$4"

    $AS "$BUSYBOX find "$keystoreTmpDir" | grep $oldUid"

    for x in `$AS "$BUSYBOX find "$keystoreTmpDir" | grep $oldUid"` ; do
        $AS "$BUSYBOX mv "$x" "${keystorePath}/`basename ${x/$oldUid/$newUid}`""
    done
}

function getPerms() {
    local permsXml="$1"
    xmlstarlet sel -T -t -m "//pkg/item"  -v "@name" -o "|" -v "@granted" -n  "$permsXml"
}


function getPipeSeparatedField() {
    local pos="$1"
    local input="$2"
    echo "$input" | awk -F'|' "{print \$$1}"
}

function generatePmGrantRevokeCmd() {
    local dataSet="$1"
    local pkgSign="$2"
    local isGranted=$(getPipeSeparatedField 2 "$dataSet")
    local permission=$(getPipeSeparatedField 1 "$dataSet")
    local actionString="revoke"

    if [ "a${isGranted}b" == "atrueb" ] ; then
        actionString="grant"
    fi

    echo "pm $actionString $pkgSign $permission"
}

function getSymlinkTarget()
{
    local appInstalledBaseDir="$1"
    local target_arch="$(determineArch)"
    local symlink_target="$appInstalledBaseDir/lib/$target_arch"

    if $AS test -d "$symlink_target" ; then
        echo "$symlink_target"
    else
        local fallback_arch="$(fallbackArch "$target_arch")"
        symlink_target="$appInstalledBaseDir/lib/$fallback_arch"
        if $AS test -d "$symlink_target" ; then
            echo "$symlink_target"
        fi
    fi
}

einfo "## Installing apps"
matchApp
APPS="$FNC_RETURN"
echo $APPS
for appPackage in $APPS; do
        #####################
        # restore app
        #####################

	APP=`tar xvfz $appPackage -C /tmp/ --wildcards "*.apk" | sed 's/\.\///'`
	edebug "appPackage=$appPackage"
	edebug "APP=$APP"
	einfo "Installing $APP"
	pushd /tmp
	error=`$A install-multiple -r -t ${APP}`
	eerror "error=$error"
	rm ${APP}
	popd

	appPrefix=$(echo $appPackage | sed 's/app_//' | sed 's/\.tar\.gz//')
	edebug "appPrefix=$appPrefix"
	allApps=`$A shell cmd package list packages -f`
	appInstalledBaseApk=$(echo "$allApps" | grep "$appPrefix$" | awk -F':' '{print $2}' | egrep -io '.*\.apk=' | sed 's@=$@@g')
	appInstalledBaseDir=$(dirname "$appInstalledBaseApk")
	#edebug "allApps=$allApps"
	appConfig=$(echo $allApps | tr " " "\n" | grep $appPrefix)
	edebug "appConfig=$appConfig"

	#dataDir=`echo $appConfig | sed 's/package://' | rev | cut -d "=" -f1 | rev`
	dataDir=$appPrefix
	edebug "dataDir=$dataDir"

        #####################
        # restore app data
        #####################
        einfo "[$appPrefix]: restoring app data"

	$AS "pm clear $appPrefix"
	sleep 1
        $AS am stop-app $appPrefix || $AS am force-stop $appPrefix
	sleep 1

	edebug "Attempting to restore data for $APP"
        appDataDir="$DATA_PATH/data/$dataDir"
        #newUid=$(getUserId "$appDataDir")
        #newGid=$(getGroupId "$appDataDir")
        newUid=$($AS dumpsys package $appPrefix | grep userId= | egrep -o '[0-9]+')
        newGid=$newUid

	if [[ -z $newUid ]]; then
	    eerror "Error: $APP still not installed"
	    exit 2
	fi

	einfo2 "APP User id is $newUid"

        ####
        # restore data
	dataPackage="${appPackage/app_/data_}"
	cat $dataPackage | pv -trab | $AS "$TAR -xzpf - -C $appDataDir"

        ####
        # fix lib symlink
        symlink="$appDataDir/lib"
        if $AS test -L "$symlink" ; then # test if there is a link
            originalSymlinkDate="$($AS "$BUSYBOX stat -c '%y' "$symlink"" | awk '{printf "%s %s\n", $1, $2}' | sed -e 's@\.[0-9]*$@@g' -e 's@ @\\ @g')"
            $AS rm "$symlink"
            symlink_target="$(getSymlinkTarget "$appInstalledBaseDir")"
            if [ "a${symlink_target}b" != "ab" ] ; then
                $AS "ln -s "$symlink_target" "$symlink""
            fi
            if $AS test -L "$symlink" ; then # change date if symlink created
                $AS "$BUSYBOX touch -ht \"$originalSymlinkDate\" "$symlink""
            fi
        fi

        ####
        # restore app data ownership
        oldUid=$(getUserId "$appDataDir")
        oldGid=$(getGroupId "$appDataDir")
        fix_perms_script=$appDataDir/${dataDir}_fix_permissions_0234fo3.sh
IFS="
"
        createDataPermUpdateScript "$appDataDir" "$oldGid" "$newGid" "$oldUid" "$newUid" | eval $AS "$BUSYBOX tee "$fix_perms_script""
        IFS="$OLDIFS"
        $AS "$BUSYBOX sh "$fix_perms_script""
        $AS "$BUSYBOX rm "$fix_perms_script""


        #####################
        # restore app extra data
        #####################
	extraDataPackage="${appPackage/app_/extradata_}"
        if test -e "$extraDataPackage" ; then
            einfo "[$appPrefix]: restoring app extra data"

            extraDataPath="$DATA_PATH/media/0/Android/data/${dataDir}"
            fix_extra_perms_script=$appDataDir/${dataDir}_fix_extra_permissions_0234fo3.sh

            $AS "$BUSYBOX mkdir -p "$extraDataPath""
	    cat $extraDataPackage | pv -trab | $AS "$TAR -xzpf - -C "$extraDataPath""
IFS="
"
            createExtDataPermUpdateScript "$extraDataPath" "$oldGid" "$newGid" | eval $AS "$BUSYBOX tee "$fix_extra_perms_script""
            IFS="$OLDIFS"
            $AS "$BUSYBOX sh "$fix_extra_perms_script""
            $AS "$BUSYBOX rm "$fix_extra_perms_script""
        else
            einfo "[$appPrefix]: NOT restoring app extra data -- no backup file"
        fi

        #####################
        # restore keystore(s)
        #####################
        keystorePath="$DATA_PATH/misc/keystore/user_0"
	keystorePackage="${appPackage/app_/keystore_}"
        if test -e "$keystorePackage" ; then
            einfo "[$appPrefix]: restoring keystores"

            keystoreTmpDir="`$AS $BUSYBOX mktemp -d`"
	    cat $keystorePackage | pv -trab | $AS "$TAR -xzpf - -C "$keystoreTmpDir""
            restoreKeystore "$keystoreTmpDir" "$oldUid" "$newUid" "$keystorePath"
            $AS "$BUSYBOX rmdir "$keystoreTmpDir""
        else
            einfo "[$appPrefix]: NOT restoring keystores -- no backup file"
        fi

        #####################
        # restore previously permissions"
        #####################
	permsPackage="${appPackage/app_/perms_}"
	permsPackage="${permsPackage/\.tar.gz/.xml}"
        if test -e "$permsPackage" ; then
            einfo "[$appPrefix]: restoring previously permissions"

            permissions=$(getPerms "$permsPackage")
            for x in ${permissions[@]} ; do
                cmd="$(generatePmGrantRevokeCmd "$x" "$appPrefix")"
                $AS "$cmd" && echo "success perms: $cmd" || echo "error perms: $cmd"
            done
        else
            einfo "[$appPrefix]: NOT restoring previously permissions -- no backup file"
        fi
done
#echo "script exiting after adb install will want to fix securelinux perms with: restorecon -FRDv /data/data"
#$AS "restorecon -FRDv /data/data" # for my phone this is not needed but maybe for others
cleanup

