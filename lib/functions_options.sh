function optionHelp()
{
    local option="$1"
    local isBackupScript=$2

    local backupOrRestore="restore"
    $isBackupScript && backupOrRestore="backup"

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
        --no-apk)
            echo "do not $backupOrRestore any apk."
            ;;
        --no-data)
            echo "do not $backupOrRestore data of app."
            ;;
        --no-ext-data)
            echo "do not $backupOrRestore external data of app. eg: /data/media/0/Android/data/pkg.example"
            ;;
        --no-keystore)
            echo "do not $backupOrRestore keystores belonging to that app."
            ;;
        --no-perms)
            echo "do not $backupOrRestore set permissions of that app."
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
