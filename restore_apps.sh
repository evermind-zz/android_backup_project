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
DO_IT=true # for try run
DO_ACTION_APK=true
DO_ACTION_DATA=true
DO_ACTION_EXT_DATA=true
DO_ACTION_KEYSTORE=true
DO_ACTION_PERMISSIONS=true
DO_UPDATE_TOOLS=false
DO_LIST_APPS_ONLY=false
DO_PRECAUTION=true

curr_dir="$(dirname "$0")"
. "$curr_dir/lib/functions_options.sh"

function displayHelp()
{
    echo
    echo "$0 is a script to restore apks, data, external data, keystores, permissions. For more information have a look at this help."
    echo
    for x in --backup-dir --data-path --debug --do-nothing --help --matching-apps --no-apk --no-data --no-ext-data --no-keystore --no-perms --single-app --update-tools --list-apps-only; do
        str="$(optionHelp "$x" false)"
        #echo "$x|$str" | column -t -s '|'   -W 2
        echo "$x|$str" | awk -F'|' '{printf "%-25s |%s\n", $1, $2}' | column -t -s '|' -E 2 -W 2
    done
    echo ""
    echo "some examples:"
    echo "=========="
    echo "# restore single app to device:"
    echo "bash restore_apps.sh --single-app \"org.videolan.vlc\""
    echo "=========="
    echo "# restore only apks to device:"
    echo "bash  restore_apps.sh --backup-dir myBackupDir --no-keystore --no-data --no-ext-data --no-perms"
}

argCount=${#@}
while [ $argCount -gt 0 ] ; do

    if [[ "$1" == "--backup-dir" ]]; then
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
    elif [[ "$1" == "--update-tools" ]]; then
        shift; let argCount-=1
        DO_UPDATE_TOOLS=true
    elif [[ "$1" == "--data-path" ]]; then
        #CUSTOM_BUSYBOX_TARGET_BIN=/tmp/busybox
        shift; let argCount-=1
        DATA_PATH=$1
        shift; let argCount-=1
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
        DO_SINGLE_APP=true
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
    elif [[ "$1" == "--no-precaution" ]]; then
        shift; let argCount-=1
        DO_PRECAUTION=false

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

. "$curr_dir/functions.sh"
. "$curr_dir/lib/functions_installer.sh"

set -e   # fail early

if $DO_PRECAUTION ; then
    einfo "###############################################################"
    einfo "# WARNING: Are you sure that your PC is connected to the correct device?"
    einfo "# Is \"$BACKUP_DIR\" the correct backup you want to restore from?"
    einfo "#"
    einfo "# Existing apps/data could be overwritten. Please doublecheck now!"
    einfo "# Type YES to continue. (you can ignore this warning with: --no-precaution"
    einfo "###############################################################"
    read answer
    if [ "a${answer}b" != "aYESb" ] ; then
        einfo "You did well and double check everything now!!!"
        exit 0
    fi
fi

OLDIFS="$IFS"

checkPrerequisites

if $DO_IT ; then

    if ! $DO_LIST_APPS_ONLY ; then
        updateBusybox "$DO_UPDATE_TOOLS"
        updateTarBinary "$DO_UPDATE_TOOLS"

        lookForAdbDevice

        checkRootType

        pushBusybox
        pushTarBinary
    fi
fi

cd "$BACKUP_DIR"

APPS=$(find -maxdepth 1 -type d -printf "%P\n" | egrep '([a-z0-9].){2,}')

function matchApp() {
    if $DO_ONLY_MATCHING_APPS ; then
        NEW_APPS=()
        for x in `echo $MATCHING_APPS | sed -e 's@|@ @g'` ; do
            NEW_APPS+=(`echo "${APPS}" | grep "^${x}$"`)
        done
        FNC_RETURN="${NEW_APPS[*]}"
	einfo "## Restoring matching app(s) in $BACKUP_DIR: "${FNC_RETURN}""
    elif $DO_SINGLE_APP ; then
        FNC_RETURN="`echo "$APPS" | grep "$SINGLE_APP"`"
	einfo "## Restoring single app in $BACKUP_DIR: "${FNC_RETURN}""
    else
        FNC_RETURN="`echo "$APPS"`"
	einfo "## Restoring all apps in $BACKUP_DIR: "${FNC_RETURN}""
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
        edebug "oldOwner $line" | sed -e 's@OLDU=@@g' -e 's@OLDG=@@g' | sed 's@^@# @'
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
    local oldGidVar2=$(($oldGid + 30000))
    local newGidVar2=$(($newGid + 30000))
    local media_rw=1023

    echo "# extDataDir: oldGid=$oldGid newGid=$newGid oldGidVar=$oldGidVar newGidVar=$newGidVar"

    eval $AS "$BUSYBOX find $workDir ! -type l -exec $BUSYBOX stat -c \"chownPATTERNOLDU=%u:OLDG=%gPATTERNBEGINrogaPATTERN%nPATTERNENDrogaPATTERN\" {} +" \
    | while read line ; do
        line="`echo "$line" | sed -e 's@PATTERN@ @g' -e 's@\"@\\\\"@g' -e 's@BEGINroga @"@g' -e 's@ ENDroga @"@g'`"
        edebug "oldOwner $line" | sed -e 's@OLDU=@@g' -e 's@OLDG=@@g' | sed 's@^@# @'
        OLDU=`echo "$line" | egrep -o 'OLDU=[^:]*' | sed -e 's@OLDU=@@g'`
        OLDG=`echo "$line" | egrep -o 'OLDG=[^ ]*' | sed -e 's@OLDG=@@g'`
        edebug "OLDU=$OLDU OLDG=$OLDG"

        # replace gid
        if [ "$OLDG" -ne "$media_rw" ] ; then
            # test if we have special GidVar
            if [ "$OLDG" -eq "$oldGidVar" ] ; then
                # replace $oldGidVar with newGidVar
                line="`echo "$line" | sed "s@OLDG=$oldGidVar@$newGidVar@g"`"
            elif [ "$OLDG" -eq "$oldGidVar2" ] ; then
                # replace $oldGidVar2 with newGidVar2
                line="`echo "$line" | sed "s@OLDG=$oldGidVar2@$newGidVar2@g"`"
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
        local targetFile="${keystorePath}/`basename ${x/$oldUid/$newUid}`"
        $AS "$BUSYBOX mv "$x" "$targetFile""
        # fix selinux context
        $AS "restorecon -FRv "$targetFile""

    done
}

function getPerms() {
    local permsXml="$1"
    cat "$permsXml" | decryptIfNeeded | xmlstarlet sel -T -t -m "//pkg/item"  -v "@name" -o "|" -v "@granted" -n
}

function getMetaAttr() {
    local attr="$1"
    local metaXml="$2"
    cat "$metaXml" | decryptIfNeeded | xmlstarlet sel -T -t -m "//package"  -v "@$attr"  -n
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

function restoreExtraData()
{
    extraDataPackage="$(getExtraDataFileName "${appPackage}")"
    if $DO_ACTION_EXT_DATA ; then
        if test -e "$extraDataPackage" ; then
            einfo "[$appSign]: restoring app extra data"

            extraDataPath="$DATA_PATH/media/0/Android/data/${dataDir}"
            fix_extra_perms_script=$appDataDir/${dataDir}_fix_extra_permissions_0234fo3.sh

            if $DO_IT ; then
                $AS "$BUSYBOX mkdir -p "$extraDataPath""
                cat "$extraDataPackage" | decryptIfNeeded | decompressor | pv -trab | $AS "$TAR -xpf - -C "$extraDataPath""
IFS="
"
                createExtDataPermUpdateScript "$extraDataPath" "$oldGid" "$newGid" | eval $AS "$BUSYBOX tee "$fix_extra_perms_script""
                IFS="$OLDIFS"
                $AS "$BUSYBOX sh "$fix_extra_perms_script""
                $AS "$BUSYBOX rm "$fix_extra_perms_script""
            fi
        else
            einfo "[$appSign]: NOT restoring app extra data -- no backup file"
        fi
    else
        einfo "[$appSign]: SKIP restoring app extra data -- as requested via commandline"
    fi
}

function restoreKeystores()
{
    keystorePath="$DATA_PATH/misc/keystore/user_0"
    keystorePackage="$(getKeystoreFileName "${appPackage}")"
    if $DO_ACTION_KEYSTORE ; then
        if test -e "$keystorePackage" ; then
            einfo "[$appSign]: restoring keystores"

            if $DO_IT ; then
                keystoreTmpDir="`$AS $BUSYBOX mktemp -d`"
                cat "$keystorePackage" | decryptIfNeeded | decompressor | pv -trab | $AS "$TAR -xpf - -C "$keystoreTmpDir""
                restoreKeystore "$keystoreTmpDir" "$oldUid" "$newUid" "$keystorePath"
                $AS "$BUSYBOX rmdir "$keystoreTmpDir""
            fi
        else
            einfo "[$appSign]: NOT restoring keystores -- no backup file"
        fi
    else
        einfo "[$appSign]: SKIP restoring keystores -- as requested via commandline"
    fi
}

function checkForEncryptedBackup()
{
    local appSign="$1"
    if [ $(find $appSign/ -name '*.enc' | wc -l) -gt 0 ] ; then
        G_DO_ENCRYPT_DECRYPT=true
        checkIfPwPresent
    fi
}

function restorePermissions()
{
    local appSign="$1"
    local permsPackage="$2"
    local whatPerms="$3"

    if test -e "$permsPackage" ; then
        einfo "[$appSign]: restoring previously permissions of $whatPerms"

        local permissions=$(getPerms "$permsPackage")
        for x in ${permissions[@]} ; do
            cmd="$(generatePmGrantRevokeCmd "$x" "$appSign")"
            $DO_IT && ($AS "$cmd" && echo "success perms: $cmd" || echo "error perms: $cmd")
        done
    else
        einfo "[$appSign]: NOT restoring previously $whatPerms permissions -- no backup file"
    fi
}

showGlobalBackupInfo

einfo "## Installing apps"

matchApp
APPS="$FNC_RETURN"
edebug "APPS=$APPS"
for appSign in $APPS; do
	edebug "appSign=$appSign"
        checkForEncryptedBackup "${appSign}"

        appPackage="$(getAppFileName "${appSign}")"
        metaPackage="$(getMetaFileName "${appPackage}")"

        installer=""
        # read original installer app from $metaPackage
        if test -e "$metaPackage" ; then
            installer=$(getMetaAttr "installer" "$metaPackage")
        fi

    if $DO_LIST_APPS_ONLY ; then
        it=$(getMetaAttr "it" "$metaPackage")
        ut=$(getMetaAttr "ut" "$metaPackage")
        einfo "APP|firstInstallTime=$(getDateForMilliSecondsSince1970 "$it")|lastUpdateTime=$(getDateForMilliSecondsSince1970 "$ut")|$appSign"
        continue
    fi

        #####################
        # restore app
        #####################

        if $DO_ACTION_APK ; then
            if test -e "$appPackage" ; then

	        APP=`cat "$appPackage" | decryptIfNeeded | tar xvzf - -C /tmp/ --wildcards "*.apk" | sed 's/\.\///'`
                einfo "[$appSign]: restoring apk(s): $APP "
	        edebug "[$appSign]: appPackage=$appPackage"
	        edebug "[$appSign]: Installing: APP=$APP"
	        if $DO_IT ; then
                    pushd /tmp &> /dev/null
	            #error=`$A install-multiple -r -t ${APP}`
	            #eerror "[$appSign]: error=$error"
                    installApks "$installer" ${APP}

	            rm ${APP}
	            popd &> /dev/null
                fi
            else
                einfo "[$appSign]: NOT restoring apk(s) -- no backup file"
            fi
        else
            einfo "[$appSign]: SKIP restoring apk(s) -- as requested via commandline"
        fi

	$DO_IT && allApps=`$A shell cmd package list packages -f`
	appInstalledBaseApk=$(echo "$allApps" | grep "$appSign$" | awk -F':' '{print $2}' | egrep -io '.*\.apk=' | sed 's@=$@@g')

        if $DO_IT && [ ${#appInstalledBaseApk} -eq 0 ] ; then
            eerror "[$appSign]: package not installed no restoring possible. Please install suitable apk first"
            exit 1
        fi
	appInstalledBaseDir=$(dirname "$appInstalledBaseApk")

	#edebug "allApps=$allApps"

	dataDir=$appSign
	edebug "[$appSign]: dataDir=$dataDir"


        if $DO_IT ; then
	    $AS "pm clear $appSign"
	    sleep 1
            $AS am stop-app $appSign || $AS am force-stop $appSign
	    sleep 1
        fi

        #####################
        # restore app data
        #####################
	edebug "[$appSign]: Attempting to restore data for $APP"
        appDataDir="$DATA_PATH/data/$dataDir"
        #newUid=$(getUserIdOfFile "$appDataDir")
        #newGid=$(getGroupIdOfFile "$appDataDir")
        if $DO_IT ; then
            newUid=$(getUserIdFromDumpsys "$appSign")
            noEmptyValueOrFail "$newUid" "\$newUid for the apk $appSign could not be read"
        fi

        newGid=$newUid

	if $DO_IT && [[ -z $newUid ]]; then
	    eerror "[$appSign]: Error: $APP still not installed"
	    exit 2
	fi

	einfo2 "[$appSign]: app user id is $newUid"

        ####
        # restore data
	dataPackage="$(getDataFileName "${appPackage}")"
        if $DO_ACTION_DATA ; then
            if test -e "$dataPackage" ; then
                einfo "[$appSign]: restoring app data"
	        $DO_IT && cat "$dataPackage" | decryptIfNeeded | decompressor | pv -trab | $AS "$TAR -xpf - -C $appDataDir"

                ####
                # fix lib symlink
                symlink="$appDataDir/lib"
                if $DO_IT && $AS test -L "$symlink" ; then # test if there is a link
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
                if $DO_IT ; then
                    oldUid=$(getUserIdOfFile "$appDataDir")
                    oldGid=$(getGroupIdOfFile "$appDataDir")
                    fix_perms_script=$appDataDir/${dataDir}_fix_permissions_0234fo3.sh
IFS="
"
                    createDataPermUpdateScript "$appDataDir" "$oldGid" "$newGid" "$oldUid" "$newUid" | eval $AS "$BUSYBOX tee "$fix_perms_script""
                    IFS="$OLDIFS"
                    $AS "$BUSYBOX sh "$fix_perms_script""
                    $AS "$BUSYBOX rm "$fix_perms_script""

                    # fix selinux context
                    $AS "restorecon -FRDv "$appDataDir""
                fi
            else
                einfo "[$appSign]: NOT restoring app data -- no backup file"
            fi
        else
            einfo "[$appSign]: SKIP restoring app data -- as requested via commandline"
        fi

        #####################
        # in case no action data to be restored we still need need to know the oldGid
        # to properly restore the extra data / keystore data
        #####################
        IS_OLDUID_OLDGID_PRESENT=true
        if ! $DO_ACTION_DATA ; then
            if test -e "$metaPackage" ; then
                oldGid=$(getMetaAttr "userId" "$metaPackage")
                oldUid=$oldGid
            else
                IS_OLDUID_OLDGID_PRESENT=false
            fi
        fi

        #####################
        # restore app extra data
        #####################
        if $IS_OLDUID_OLDGID_PRESENT ; then
            restoreExtraData
        else
            einfo "[$appSign]: IMPOSSIBLE restoring app extra data -- as oldUid/oldGid not found in $metaPackage"
        fi

        #####################
        # restore keystore(s)
        #####################
        if $IS_OLDUID_OLDGID_PRESENT ; then
            restoreKeystores
        else
            einfo "[$appSign]: IMPOSSIBLE restoring keystores -- as oldUid/oldGid not found in $metaPackage"
        fi

        #####################
        # restore previously permissions"
        #####################
        if $DO_ACTION_PERMISSIONS ; then
            permsPackage=$(getPermFileName "${appPackage}")
            restorePermissions "$appSign" "$permsPackage" "app"

            permsSharedUserPackage=$(getPermSharedUserFileName "${appPackage}")
            restorePermissions "$appSign" "$permsSharedUserPackage" "shared user"
        else
            einfo "[$appSign]: SKIP restoring previously permissions -- as requested via commandline"
        fi
done
#echo "script exiting after adb install will want to fix securelinux perms with: restorecon -FRDv /data/data"
#$AS "restorecon -FRDv /data/data" # for my phone this is not needed but maybe for others
if ! $DO_LIST_APPS_ONLY ; then
    $DO_IT && cleanup
fi

