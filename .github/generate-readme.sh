#!/bin/bash

readmeFile=".github/README.md"
function echol() {
    echo "$@" >> "$readmeFile"
}

cat <<EOF> $readmeFile
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
- backup of keystores (may fail if changing phone and/or the implementation is in hardware)
- backup of external data
- backup of external data on microSD card
- loads of command line switches
- restore also the previous installer app signature. eg. com.android.vending
- Unix permissions/ownership set (hopefully) correctly.
- fix lib symlink in data

EOF
echol '## backup_apps.sh commandline --switches'
echol '```'
echol '$ bash backup_apps.sh --help'
echol "`bash backup_apps.sh --help`"

echol '```'
echol ''
echol '## restore_apps.sh commandline --switches'
echol '```'
echol '$ bash restore_apps.sh --help'
echol "`bash restore_apps.sh --help`"
echol '```'
echol ""
echol '## app-installer.sh commandline --switches'
echol "This script is just a wrapper to help install apks onto your device. But maybe you prefer using adb directly."
echol '```'
echol "$ bash app-installer.sh --help"
echol "`bash app-installer.sh --help`"
echol '```'
