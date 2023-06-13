#!/bin/bash

curr_dir="$(dirname "$0")"
. "$curr_dir/functions.sh"
. "$curr_dir/lib/functions_installer.sh"

function printHelp() {
    local input="`egrep -o -- '--.*]].*;.*#.*' $0`"
    local inputCopy="$input"

    # find longest argument to get the output nice
    local longest=0
    while [[ "$input" =~ (--[a-zA-Z0-9-]*)\"\ *]][^#]*#\ *([^#]*)#(.*) ]] ; do
        if [ ${#BASH_REMATCH[1]} -gt $longest ] ; then
            longest=${#BASH_REMATCH[1]}
        fi
        input=${BASH_REMATCH[3]}
    done

    # print the help
    let longest+=5 # spaces more
    while [[ "$inputCopy" =~ (--[a-zA-Z0-9-]*)\"\ *]][^#]*#\ *([^#]*)#(.*) ]] ; do
        printf "%-${longest}s %s\n" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        inputCopy=${BASH_REMATCH[3]}
    done
    exit 0
}

function checkIfDirExists() {
    if [ "a${1}b" == "ab" ] ; then
        eerror "[Error]: You have to specify a dir with $2"
        exit 1
    fi
    if ! test -e $1; then
        eerror "[Error]: the dir you specified does not exist:"
        eerror "\"$1\""
        exit 1
    fi
}

APK_FILES=()
SPLIT_APK_FILES=()

APP_SPLIT_APKS_DIR=""
APPS_APK_DIR=""

INSTALLER_NAME=""
DO_INSTALL=false
DO_LIST=false

argCount=${#@}
while [ $argCount -gt 0 ] ; do
    if [[ "$1" == "--install" ]]; then # install apk(s) you specified with --apk-*#
        shift; let argCount-=1
        DO_INSTALL=true
    elif [[ "$1" == "--list" ]]; then # list apk(s) you specified with --apk-*#
        shift; let argCount-=1
        DO_LIST=true
    elif [[ "$1" == "--apk-files" ]]; then # apk(s) that are complete app(s)#
        shift; let argCount-=1
        if [ "a${1}b" == "ab" ] || [[ ${1} =~ ^--[a-zA-Z] ]] ; then
            echo "[Error]: You have to specify files here"
            exit 1
        fi
        while ([ "a${1}b" != "ab" ] && ! [[ ${1} =~ ^--[a-zA-Z] ]]) ; do
            APK_FILES+=($1)
            shift; let argCount-=1
        done
    elif [[ "$1" == "--apk-files-split" ]]; then # apk paths for a split app#
        shift; let argCount-=1
        if [ "a${1}b" == "ab" ] || [[ ${1} =~ ^--[a-zA-Z] ]] ; then
            echo "[Error]: You have to specify files here"
            exit 1
        fi
        while ([ "a${1}b" != "ab" ] && ! [[ ${1} =~ ^--[a-zA-Z] ]]) ; do
            SPLIT_APK_FILES+=($1)
            shift; let argCount-=1
        done
    elif [[ "$1" == "--apk-dir" ]] ; then # the path to the dir with (none split) apk(s) for app(s)#
        shift; let argCount-=1
        DO_APK_DIR=true
        checkIfDirExists "$1" "apks you want"
        APPS_APK_DIR=$1
        shift; let argCount-=1
    elif [[ "$1" == "--apk-dir-split" ]] ; then # the path to the dir with (split) apks for single app#
        shift; let argCount-=1
        DO_APKS_SPLIT_DIR=true
        checkIfDirExists "$1" "apks you want"
        APP_SPLIT_APKS_DIR=$1
        shift; let argCount-=1
    elif [[ "$1" == "--installer-name" ]] ; then # the name of the installer to state: eg "com.android.vending" #
        shift; let argCount-=1
        INSTALLER_NAME=$1
        shift; let argCount-=1
    elif [[ "$1" == "--help" ]]; then # show this help #
        shift; let argCount-=1
        printHelp
    else
        echo "ERROR unknown parameter: $1"
        exit
    fi
done

function installApks() {
    local installer="$1" ; shift
    local noOfApks="${#@}"

    if [ "a${REMOTE_TMP_APK_DIR}b" == "ab" ] ; then
        REMOTE_TMP_APK_DIR="$(createRemoteTmpApkDir "$REMOTE_TMP_BASE_PATH")"
    fi

    pushApksToRemoteTmpDir "$REMOTE_TMP_APK_DIR" $@
    installSplitApks "$installer" "$REMOTE_TMP_APK_DIR"
    cleanTmpDirFromApks "$REMOTE_TMP_APK_DIR"
}

function installSplits() {
    if [ ${#SPLIT_APK_FILES[@]} -gt 0 ] ; then
        if $DO_LIST ; then
            for x in ${SPLIT_APK_FILES[@]} ; do
                einfo $x
            done
        else
            installSplitApks "$INSTALLER_NAME" ${SPLIT_APK_FILES[@]}
        fi
    fi
}

function installNoneSplits() {
    for apk in ${APK_FILES[@]} ; do
        if $DO_LIST ; then
            einfo $apk
        else
            installSplitApks "$INSTALLER_NAME" "${apk}"
        fi
    done
}

########### script flow ###########
if $DO_INSTALL || $DO_LIST; then
    # install split app apks
    installSplits
    if [ "a${APP_SPLIT_APKS_DIR}b" != "ab" ] ; then
        SPLIT_APK_FILES=(`find $APP_SPLIT_APKS_DIR -iname '*.apk'`)
        installSplits
    fi

    # install apps that are not split
    installNoneSplits
    if [ "a${APPS_APK_DIR}b" != "ab" ] ; then
        APK_FILES=(`find $APPS_APK_DIR -iname '*.apk'`)
        installNoneSplits
    fi
    removeTmpApkDir "$REMOTE_TMP_APK_DIR"
fi
