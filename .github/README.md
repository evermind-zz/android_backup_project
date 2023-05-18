[Original Readme](../README.md)
# Motivation for this Fork
Somehow my phone did not start one day and I had to restore it. Luckily I
could still access my data via recovery and could fetch a tarballed copy
of the '/data' partition. I searched the internet and found this project
[https://github.com/AndDiSa/android_backup_project].

I started to adapt the script to read from my local '/data' copy. In that
process I started to rewrite much of the backup/restore code (of backup_apps.sh
and restore_apps.sh) and extended its functionality.

My goal was to have a script that tries to restore as much as possible to
the original state. Eg. setting the Unix permission exactly like they were
before, have external data, keystores, permissions and more.

The scripts were developed and tested only on rooted android 7 and 10.

## Additional features
- encryption of backup
- backup of keystores
- backup of external data
- backup of external data on microSD card
- loads of command line switches
- restore also the previous installer app signature. eg. com.android.vending
- Unix permissions/ownership set (hopefully) correctly.
- fix lib symlink in data

## backup_apps.sh commandline --switches
```
$ bash backup_apps.sh --help

backup_apps.sh is a script to backup apks, data, external data, keystores, permissions and external app related data from sdcard. For more information have a look at this help.

--backup-dir                where to put the backup. Use always in combination with --local. If backup from device (without this option) there is a generated
                            backup dir
--data-path                 path to the mountpoint '/data'. Default is '/data'. Useful in combination with --local where you have a copy of the '/data' partit
                            ion somewhere.
--debug                     display some more messages.
--encrypt                   encrypt backup on the fly.
--ext-data-sdcard           backup also data from an external (micro)SD card related to the app you want to backup up. eg: /mnt/media_rw/<SDCARD_MOUNTPOINT>/A
                            ndroid/data/pkg.example. Restore only manually possible.
--local                     state that this is doing a backup from a copy of your phone's '/data' partition on your PC.
--matching-apps             only backup matching apps. eg: --matching-apps "org.mozilla.firefox
--no-apk                    do not backup any apk.
--no-data                   do not backup data of app.
--no-ext-data               do not backup external data of app. eg: /data/media/0/Android/data/pkg.example
--no-keystore               do not backup keystores belonging to that app.
--no-perms                  do not backup set permissions of that app.
--single-app                only backup this single app. eg: --single-app org.videolan.vlc
--system-apps               include system apps in backup
--system-apps-only          include only system apps in backup
--update-tools              force updating tools via git. At the moment tar and busybox
--use-busybox-selinux       force to use selinux busybox version on some systems
--help                      Display this help
--list-apps-only            list apps only that might be backup

some examples:
==========
# create backup from local '/data' dump from single app:
bash backup_apps.sh  --local --single-app org.videolan.vlc --data-path /path/to/datadump  --backup-dir myBackupDir
==========
# create backup from device matching appsingle app:
bash backup_apps.sh --matching-apps "com.starfinanz.mobile.android.dkbpushtan|com.github.bravenewpipe"
==========
# backup all user apks from device:
bash  backup_apps.sh --backup-dir myBackupDir2 --no-keystore --no-data --no-ext-data --no-perms
```

## restore_apps.sh commandline --switches
```
$ bash restore_apps.sh --help
WARNING: restoring random system apps is quite likely to make things worse
unless you are copying between 2 identical devices.
You probably want to mv backupdir/app_{com.android,com.google}* /backup/location
This will cause this script not to try and restore system app data


restore_apps.sh is a script to restore apks, data, external data, keystores, permissions. For more information have a look at this help.

--backup-dir                the directory with the backup that should be restored
--data-path                 path to the mountpoint '/data'. Default is '/data'. Useful in combination with --local where you have a copy of the '/data' partit
                            ion somewhere.
--debug                     display some more messages.
--do-nothing                mostly do nothing. This option is not properly tested --> TODO.
--help                      Display this help
--matching-apps             only restore matching apps. eg: --matching-apps "org.mozilla.firefox
--no-apk                    do not restore any apk.
--no-data                   do not restore data of app.
--no-ext-data               do not restore external data of app. eg: /data/media/0/Android/data/pkg.example
--no-keystore               do not restore keystores belonging to that app.
--no-perms                  do not restore set permissions of that app.
--single-app                only restore this single app. eg: --single-app org.videolan.vlc
--update-tools              force updating tools via git. At the moment tar and busybox
--list-apps-only            list apps only that might be restore
--no-precaution             Do not force user to confirm that he might overwrite files on the device

some examples:
==========
# restore single app to device:
bash restore_apps.sh --single-app "org.videolan.vlc"
==========
# restore only apks to device:
bash  restore_apps.sh --backup-dir myBackupDir --no-keystore --no-data --no-ext-data --no-perms
```
