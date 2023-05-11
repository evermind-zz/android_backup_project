#!/bin/bash

A="adb"
AMAGISK="adb shell su root "      # -- needed for magisk rooted devices
AMAGISK2="adb shell su 0 -c "     # -- needed for magisk rooted devices (depends on su version installed)
AMAGISK3="adb shell su -c "       # -- needed for magisk rooted devices (depends on su version installed)
AROOT="adb shell "
BUSYBOX="${CUSTOM_BUSYBOX_TARGET_BIN:-/dev/busybox}"
# gnu tar is used as it also restores the date of
# root folder we expanding to. Busybox's tar will fail
# at least this version: 'v1.34.1-osm0sis' fails.
# no idea if other versions have fixed that
TAR="${CUSTOM_TAR_TARGET_BIN:-/dev/tar}"
G_DEBUG=${DEBUG:-false}
G_DO_ENCRYPT_DECRYPT=${DO_ENCRYPT:-false}

l_repoTarGitUrl=https://github.com/Zackptg5/Cross-Compiled-Binaries-Android
l_repoTarDir=$(basename $l_repoTarGitUrl)

encPwd="ASDLFWErbfak"
g_encExt=".enc"

function einfo()
{
    echo "$@"
}

function einfo2()
{
    echo "$@" 1>&2
}

function edebug()
{
    if $G_DEBUG ; then
        echo "DBG: $@" 1>&2
    fi
}

function eerror()
{
    echo "$@" 1>&2
}

function cleanup()
{
	$AS rm "$BUSYBOX"
	$AS rm "$TAR"
}

function getExtensionIfEncryptSelected()
{
    $G_DO_ENCRYPT_DECRYPT && echo "${g_encExt}"
}

function getGlobalMetaDataFileName()
{
    echo "global_meta.xml$(getExtensionIfEncryptSelected)"
}

function getAppFileName()
{
    local apkSign="$1"
    echo "$apkSign/app_${apkSign}.tar.gz$(getExtensionIfEncryptSelected)"
}

function getDataFileName()
{
    local appPackage="$1"
    echo "${appPackage/app_/data_}"
}

function getExtraDataFileName()
{
    local appPackage="$1"
    echo "${appPackage/app_/extradata_}"
}

function getKeystoreFileName()
{
    local appPackage="$1"
    echo "${appPackage/app_/keystore_}"
}

function getPermFileName() {
    local appPackage="$1"
    local permsPackage="${appPackage/app_/perms_}"
    permsPackage="${permsPackage/\.tar.gz/.xml}"
    echo "$permsPackage"
}

function getMetaFileName() {
    local appPackage="$1"
    local permsPackage=$(getPermFileName "${appPackage}") # get xml extension
    local metaPackage="${permsPackage/perms_/meta_}"
    echo "$metaPackage"
}

function checkForCleanData()
{
	if ! [ "$($AS ls /data/ | wc -l)" -gt 1 ]; then
		$AS mount /data
	fi

	if ! [ "$($AS ls /data/ | wc -l)" -gt 4 ]; then
		echo "It seems like /data is not in a sane state!"
		$AS ls /data || :
		$AS stat /data || :
		exit 1
	fi
}

function checkPrerequisites()
{
	adb=`adb --version`
        if [ $? -ne 0 ]; then
                echo "adb not found, please install adb"
                exit 1
        fi

	git=`git --version`
        if [ $? -ne 0 ]; then
                echo "git not found, please install git"
                exit 1
        fi

	tar=`tar --help`
        if [ $? -ne 0 ]; then
                echo "tar not found, please install tar"
                exit 1
	fi 

        wc=`wc --help`
        if [ $? -ne 0 ]; then
                echo "wc not found, please install wc"
                exit 1
        fi

        tr=`tr --help`
        if [ $? -ne 0 ]; then
                echo "tr not found, please install tr"
                exit 1
        fi

        sed=`sed --help`
        if [ $? -ne 0 ]; then
                echo "sed not found, please install sed"
                exit 1
        fi

        rev=`rev --help`
        if [ $? -ne 0 ]; then
                echo "rev not found, please install rev"
                exit 1
        fi

        cut=`cut --help`
        if [ $? -ne 0 ]; then
                echo "cut not found, please install cut"
                exit 1
        fi

        gzip=`gzip --help`
        if [ $? -ne 0 ]; then
                echo "gzip not found, please install gzip"
                exit 1
        fi

	pv=`pv -V`
	if [ $? -ne 0 ]; then
		echo "pv not found, please install pv"
		exit 1
	else
		v=`echo $pv | head -n 1 | cut -d " " -f2`
		if [ "$v" \< "1.6.6" ]; then
			echo "$v of pv is lower than required version: 1.6.6"
			exit 1
		fi
	fi
}

function checkRootType()
{
	echo "Checking for root access..."
	echo "1) Requesting adbd as root..."
	$A root
	echo "Waiting for device..."
	$A wait-for-any-device

	result=`$AROOT whoami`
	echo $result
	if [[ "$result" == "root" ]]; then
		AS=$AROOT
	else
		result=`$AMAGISK3 whoami`
		echo $result
        	if [[ "$result" == "root" ]]; then
        		AS=$AMAGISK3
		else

			result=`$AMAGISK2 whoami`
			echo $result
        		if [[ "$result" == "root" ]]; then
        			AS=$AMAGISK2
			else
				result=`$AMAGISK whoami`
				echo $result
	                	if [[ "$result" == "root" ]]; then
                        		AS=$AMAGISK
				else
					echo "Fianlly root is not available for this device, exiting execution."
					exit 1
				fi
			fi
		fi
	fi
}

function lookForAdbDevice()
{
	echo "Waiting for device..."
	$A wait-for-any-device

	echo "Devices detected:"
	$A devices
}

function mkBackupDir()
{
	HW=`$AS getprop ro.hardware | tr -d '\r'`
	BUILD=`$AS getprop ro.build.id | tr -d '\r'`

	DATE=`date +%F`
	BACKUP_DIR="${HW}_${DATE}_${BUILD}"
	if test -d "$BACKUP_DIR"; then
            echo "$BACKUP_DIR already exists, exiting"
            exit 2
	fi

	echo "### Creating dir $BACKUP_DIR"
	mkdir -p $BACKUP_DIR
}

function fallbackArch()
{
	einfo2 "Determining architecture..."
	local target_arch="$1"
        local fallbackArch=""
	case $target_arch in
		arm|arm64)
			fallback_arch=arm
			;;
		mips|mips64)
			fallback_arch=mips
			;;
		x86|x86_64)
			fallback_arch=x86
			;;
		*)
			einfo2 "Unrecognized architecture $target_arch"
			exit 1
			;;
	esac
        echo $fallback_arch
}

function determineArch()
{
	einfo2 "Determining architecture..."
	local target_arch="$($AS uname -m)"
	case $target_arch in
		aarch64|arm64|armv8|armv8a)
			target_arch=arm64
			;;
		aarch32|arm32|arm|armv7|armv7a|armv7l|armv8l|arm-neon|armv7a-neon|aarch|ARM)
			target_arch=arm
			;;
		mips|MIPS|mips32|arch-mips32)
			target_arch=mips
			;;
		mips64|MIPS64|arch-mips64)
			target_arch=mips64
			;;
		x86|x86_32|IA32|ia32|intel32|i386|i486|i586|i686|intel)
			target_arch=x86
			;;
		x86_64|x64|amd64|AMD64|amd)
			target_arch=x86_64
			;;
		*)
			einfo2 "Unrecognized architecture $target_arch"
			exit 1
			;;
	esac
        echo $target_arch
}

function pushBinary() {
        local binaryName="$1"
        local srcBinary="$2"
        local targetBinary="$3"
        local targetBinaryArgsToMakeExitCleanly="$4" # eg --help

        if $AS test -e "$targetBinary" ; then
            $AS rm "$targetBinary"
        fi
        cat "$srcBinary" | $AS tee $targetBinary > /dev/null
	$AS chmod +x $targetBinary

	if ! $AS $targetBinary $targetBinaryArgsToMakeExitCleanly >/dev/null; then
		echo "$binaryName doesn't work here!"
		exit 1
	fi
}

function pushTarBinary()
{
        local target_arch="$(determineArch)"
	echo "Pushing tar to device..."

        if [ "a${target_arch}b" == "ax86_64b" ]; then
            target_arch="x64"
        fi
        pushBinary "Tar" "$l_repoTarDir/tar/tar-$target_arch" "$TAR" "--help"
}

function pushBusybox()
{
        local useSelinuxVersion="$1"
        local selinuxPostfix=""
        [ "a${useSelinuxVersion}b" != "ab" ] && selinuxPostfix="-selinux"
        local target_arch="$(determineArch)"
	echo "Pushing busybox to device..."
	pushBinary "Busybox" "busybox-ndk/busybox-${target_arch}${selinuxPostfix}" "$BUSYBOX" "--help"
}

function stopRuntime()
{
	echo "## Stop Runtime" && $AS stop
}

function startRuntime()
{
	echo "## Restart Runtime" && $AS start
}

function updateTarBinary()
{
    if [ ! -d "$l_repoTarDir" ]; then
        git clone --depth 1 --filter=blob:none --sparse "$l_repoTarGitUrl"
        pushd "$l_repoTarDir" &> /dev/null
        git sparse-checkout set tar
        popd &> /dev/null
    else
        pushd "$l_repoTarDir" &> /dev/null
        git pull
        popd &> /dev/null
    fi
}

function updateBusybox()
{
	if [ ! -d busybox-ndk ]; then
		git clone https://github.com/Magisk-Modules-Repo/busybox-ndk
	else
		pushd busybox-ndk &> /dev/null
		git pull
		popd &> /dev/null
	fi
}

function getUserId()
{
        $AS $BUSYBOX stat -c "%u" "$1"
}

function getGroupId()
{
        $AS $BUSYBOX stat -c "%g" "$1"
}

function checkIfPwPresent()
{
    if [ "a${!encPwd}b" == "ab" ] ; then
        read -p "please enter password to encrypt/decrypt: " -s pw
        export ${encPwd}="$pw"
        unset pw
        echo
    fi
}

function encryptIfSelected()
{
    if $G_DO_ENCRYPT_DECRYPT ; then
        openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -e -pass env:$encPwd
    else
        tee
    fi
}

function decryptIfNeeded()
{
    local forceDecrypt="${1:-ignore}" # values are: yes, ignore, no (no could be everything
    if ($G_DO_ENCRYPT_DECRYPT && [ "a${forceDecrypt}b" == "aignoreb" ] ) || [ "a${forceDecrypt}b" == "ayesb" ]; then
        openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -d -pass env:$encPwd
    else
        tee
    fi
}

function showGlobalBackupInfo()
{
    local globalmetadataFile=$(getGlobalMetaDataFileName)
    local fileName=""

    # determine if a global meta data file exists
    # and if it is encrypted or not
    if test -e ${globalmetadataFile/${g_encExt}/} ; then # not encrypted case
        forceDecrypt="no"
        fileName="${globalmetadataFile/${g_encExt}/}"
    elif test -e "${globalmetadataFile/${g_encExt}/}${g_encExt}" ; then # look for encrypted
        checkIfPwPresent
        forceDecrypt="yes"
        fileName="${globalmetadataFile/${g_encExt}/}${g_encExt}"
    else
        return
    fi

    local info="`cat "$fileName" | decryptIfNeeded "$forceDecrypt" | xmlstarlet sel -T -t -m "//packages/version"  -o sdkVersion= -v "@sdkVersion" -o "|fingerprint=" -v "@fingerprint" -o "|volumeUuid=" -v "@volumeUuid" -n`"
    einfo "=>>==============="
    einfo "Basic backup info"
    einfo "=================="
    einfo "$info"
    einfo "=<<==============="
    unset _decodeOrNot
}
