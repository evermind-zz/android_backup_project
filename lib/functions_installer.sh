function createRemoteTmpApkDir() {
    local tmpBaseDir="$1"
    local tempdir=$($A shell mktemp -d -p "$tmpBaseDir")
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
function doesTmpApkDirExistAndIsValid() {
    local tempdir="$1"
    if [ "a${tempdir}b" != "ab" ] && [ "a${tempdir}b" != "a/b" ] && \
        [[ $tempdir =~  ^/data/local/tmp/[a-z]+ ]] && $A shell test -e "$tempdir" ; then
        return 0
    else
        return 1
    fi
}

function removeTmpApkDir() {
    local tempdir="$1"
    if doesTmpApkDirExistAndIsValid "$tempdir" ; then
        $A shell find "$tempdir"
        $A shell rmdir "$tempdir"
    fi
}

# remove all apks from given tmpDir
# Note: this method assumes that $REMOTE_TMP_APK_DIR dir below /data/local/tmp/
function cleanTmpDirFromApks() {
    local tempdir="$1"
    if doesTmpApkDirExistAndIsValid "$tempdir" ; then
        $A shell find "$tempdir"
        $A shell rm "$tempdir"/*.apk
    fi
}
