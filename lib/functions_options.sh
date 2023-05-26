
DO_ACTION_APK=true
DO_ACTION_DATA=true
DO_ACTION_EXT_DATA=true
DO_ACTION_KEYSTORE=true
DO_ACTION_PERMISSIONS=true

# helper var for areActionOnlyAlreadyActivatedIfNotActivate() function
L_ARE_ACTION_RESET=false

function optionHelp()
{
    local option="$1"
    local isBackupScript=$2

    local backupOrRestore="restore"
    $isBackupScript && backupOrRestore="backup"

    # determine if option is a --only-* action and set help accordingly
    local onlyOptionText="not"
    [[ $option =~  --only-.* ]] && onlyOptionText="only"

    case $option in
        --backup-dir)
            if $isBackupScript ; then
                echo "where to put the backup. Use always in combination with --local. If backup from device (without this option) there is a generated backup dir"
            else
                echo "the directory with the backup that should be restored"
            fi
            ;;
        --data-path)
            echo "path to the mountpoint '/data'. Default is '/data'. Useful in combination with --local where you have a copy of the '/data' partition somewhere."
            ;;
        --debug)
            echo "display some more messages."
            ;;
        --do-nothing)
            echo "mostly do nothing. This option is not properly tested --> TODO."
            ;;
        --encrypt)
            echo "encrypt backup on the fly."
            ;;
        --ext-data-sdcard)
            echo "backup also data from an external (micro)SD card related to the app you want to backup up. eg: /mnt/media_rw/<SDCARD_MOUNTPOINT>/Android/data/pkg.example. Restore only manually possible."
            ;;
        --extra-data)
            echo "TODO this option is redundant"
            ;;
        --local)
            echo "state that this is doing a backup from a copy of your phone's '/data' partition on your PC."
            ;;
        --matching-apps)
            echo "only $backupOrRestore matching apps. eg: --matching-apps \"org.mozilla.firefox|org.videolan.vlc\""
            ;;
        --no-apk|--only-apk)
            echo "do $onlyOptionText $backupOrRestore apk(s)."
            ;;
        --no-data|--only-data)
            echo "do $onlyOptionText $backupOrRestore data of app(s)."
            ;;
        --no-ext-data|--only-ext-data)
            echo "do $onlyOptionText $backupOrRestore external data of app(s). eg: /data/media/0/Android/data/pkg.example"
            ;;
        --no-keystore|--only-keystore)
            echo "do $onlyOptionText $backupOrRestore keystore(s)."
            ;;
        --no-perms|--only-perms)
            echo "do $onlyOptionText $backupOrRestore permissions of app(s)."
            ;;
        --single-app)
            echo "only $backupOrRestore this single app. eg: --single-app org.videolan.vlc"
            ;;
        --system-apps)
            echo "include system apps in backup"
            ;;
        --system-apps-only)
            echo "include only system apps in backup"
            ;;
        --list-apps-only)
            echo "list apps only that might be $backupOrRestore"
            ;;
        --update-tools)
            echo "force updating tools via git. At the moment tar and busybox"
            ;;
        --use-busybox-selinux)
            echo "force to use selinux busybox version on some systems"
            ;;
        --help)
            echo "Display this help"
            ;;
        --no-precaution)
            echo "Do not force user to confirm that he might overwrite files on the device"
            ;;
        *)
            echo "Unrecognized option $option"
            exit 1
            ;;
    esac
}

function setVariablesToFirstArg() {
    local toWhat=$1 ; shift
    local pointerVar="DA_$RANDOM"

    for varname in ${@} ; do
        export ${pointerVar}="$varname"
        export ${!pointerVar}=$toWhat
    done
}

function showVariableNameAndValue() {
    local pointerVar="DA_$RANDOM"

    for varname in ${@} ; do
        export ${pointerVar}="$varname"
        echo "${!pointerVar}=${!varname}"
    done
}

function areActionOnlyAlreadyActivatedIfNotActivate() {
    if $L_ARE_ACTION_RESET ; then
        return 0
    else
        L_ARE_ACTION_RESET=true
        return 1
    fi
}

function resetActions() {
    if ! areActionOnlyAlreadyActivatedIfNotActivate ; then
        setVariablesToFirstArg false DO_ACTION_APK DO_ACTION_DATA DO_ACTION_EXT_DATA DO_ACTION_KEYSTORE DO_ACTION_PERMISSIONS
    fi
}

function printPretty() {
    local option="$1"
    local descr="$2"
    echo "$option;$descr" | awk -F';' '{printf "%-25s ;%s\n", $1, $2}' | column -t -s ';' -E 2 -W 2
}
