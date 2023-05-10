function createRemoteTmpApkDir() {
    local tempdir=$($A shell mktemp -d)
    echo $tempdir
}

function pushApksToRemoteTmpDir() {
    local tempdir="$1" ; shift
    local inputfiles=$@
    $A push $inputfiles $tempdir
}

# source info for -i https://medium.com/@pixplicity/setting-the-install-vendor-of-an-app-7d7deacb01ee
function doWeNeedInstallerSwitch() {
    local installer="$1"
    if [ "a${installer}b" == "ab" ] ;then
        echo -n
    else
        echo "-i"
    fi
}

function installSplitApks() {
    local installer="$1"
    local tempdir="$2"
    local total_size=$($A shell du "$tempdir"/*.apk | awk '{print $1}' | xargs | sed -e 's@ @ + @g' | bc)
    local session_id=$($A shell pm install-create $(doWeNeedInstallerSwitch "$installer") "$installer" -t -r -S $total_size | egrep -o '[0-9]*')

    local index=0
    for x in `$A shell ls $tempdir/*.apk` ; do
        $A shell pm install-write -S $($A shell du -s "$x" | awk '{print $1}') $session_id $index $x
        let index+=1
    done

    $A shell pm install-commit $session_id
}

function removeTmpApkDir() {
    local tempdir="$1"
    if echo $tempdir | egrep -q '^/data/local/tmp/[a-z]+' && adb shell test -e $tempdir ; then
        echo "rm -rf $tempdir"

        $A shell find "$tempdir"
        $A shell rm "$tempdir"/*.apk
        $A shell rmdir "$tempdir/"
    fi
}

function installApks() {
    local installer="$1" ; shift
    local remoteTmpApkDir="$(createRemoteTmpApkDir)"
    local noOfApks="${#@}"

    pushApksToRemoteTmpDir "$remoteTmpApkDir" $@

    #if [ "$noOfApks" -eq 1 ] ; then
    #    local remoteApkFile
    #    adb shell pm install $(doWeNeedInstallerSwitch "$installer") "$installer" -t -r "$1"
    #elif [ "$noOfApks" -gt 1 ] ; then
        installSplitApks "$installer" "$remoteTmpApkDir"
    #fi

    removeTmpApkDir "$remoteTmpApkDir"
}
