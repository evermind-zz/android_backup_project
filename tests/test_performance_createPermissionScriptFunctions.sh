#!/bin/bash
# test to compare the old create{Ext}DataPermUpdateScript() functions
# and to test if the output is the same
# -> there is a tarball with test app data and data from the external storage
#    aka. /data/media/0/Android/data/your.app.sign/
###########################

. "../lib/functions_restore.sh"
. "performance_createPermissionScriptFunctions/functions_restore_old.sh"
. "../functions.sh"
. "./lib/functions_measure.sh"

OLDIFS=$IFS

AS="sudo "
#AS="adb shell su -c "
BUSYBOX="$PWD/../busybox-ndk/busybox-arm64-selinux"
#BUSYBOX="/dev/busybox"
testDataDir="performanceTestData"
testDataTarball="performance_createPermissionScriptFunctions/data_extData_testFiles.tgz"
appSign="test.performance"

#appDataDir=/data/media/0/magaladaga # original for on device testing
appDataDir=$testDataDir/data
#extraDataPath="$DATA_PATH/media/0/Android/data/${appSign}" # original for on device testing
extraDataPath=$testDataDir/extData



function setupTestData() {
	mkdir -p "$testDataDir"
	sudo tar xzpf "$testDataTarball" -C "$testDataDir"

	oldUid=$(getUserIdOfFile "$appDataDir")
	oldGid=$(getGroupIdOfFile "$appDataDir")
	newUid=12345
	newGid=$newUid
}

function cleanupTestData() {
	if [ "a${testDataDir}b" != "ab" ] && [ "a${testDataDir}b" != "a/b" ] &! [[ ${testDataDir} =~ \* ]] && test -e "$testDataDir" ; then
		rm -rf "$testDataDir"
	fi
}

function restoreDataTest() {
	einfo "[$appSign]: restoring app data test"

	fix_perms_script=$appDataDir/${appSign}_fix_permissions_0234fo3.sh
	fix_perms_scriptBak=$appDataDir/${appSign}_fix_permissions_0234fo3.sh.bak
	IFS="
	"
	measureStart
	createDataPermUpdateScriptOld "$appDataDir" "$oldGid" "$newGid" "$oldUid" "$newUid" | grep -v $fix_perms_script | eval $AS "$BUSYBOX tee "$fix_perms_script"" | egrep '(GIDERROR|UIDERROR)'
	measureEnd
	timingResult="`measureResult "old createDataPermUpdateScript()"`" # <-- createDataPermUpdateScriptOld
	firstChecksum="`eval $AS "$BUSYBOX md5sum "$fix_perms_script"" | awk '{print $1}'`"
	eval $AS "$BUSYBOX mv "$fix_perms_script" "$fix_perms_scriptBak""

	measureStart
	createDataPermUpdateScript "$appDataDir" "$oldGid" "$newGid" "$oldUid" "$newUid" | grep -v $fix_perms_script | eval $AS "$BUSYBOX tee "$fix_perms_script"" | egrep '(GIDERROR|UIDERROR)'
	measureEnd
	echo "$timingResult"
	measureResult "new createDataPermUpdateScript()"

	secondChecksum="`eval $AS "$BUSYBOX md5sum "$fix_perms_script"" | awk '{print $1}'`"

	IFS="$OLDIFS"
	if [ "$firstChecksum" != "$secondChecksum" ] ; then
		echo "not equal $fix_perms_script"
		echo "not equal $fix_perms_scriptBak"
		echo "[Test Failed] restoreExtraDataTest"
	fi
	IFS="$OLDIFS"
}

function restoreExtraDataTest() {
	extraDataPackage="$(getExtraDataFileName "${appPackage}")"
	einfo "[$appSign]: restoring app extra data test"

	fix_extra_perms_script=$appDataDir/${appSign}_fix_extra_permissions_0234fo3.sh
	fix_extra_perms_scriptBak=$appDataDir/${appSign}_fix_extra_permissions_0234fo3.sh.bak

	IFS="
	"
	measureStart
	createExtDataPermUpdateScriptOld "$extraDataPath" "$oldGid" "$newGid" | grep -v $fix_extra_perms_script | eval $AS "$BUSYBOX tee "$fix_extra_perms_script"" | egrep '(GIDERROR|UIDERROR)'
	measureEnd
	timingResult="`measureResult "old createExtDataPermUpdateScript()"`" # <-- createExtDataPermUpdateScriptOld()
	firstChecksum="`eval $AS "$BUSYBOX md5sum "$fix_extra_perms_script"" | awk '{print $1}'`"
	eval $AS "$BUSYBOX mv "$fix_extra_perms_script" "$fix_extra_perms_scriptBak""
	measureStart
	createExtDataPermUpdateScript "$extraDataPath" "$oldGid" "$newGid" | grep -v $fix_extra_perms_script | eval $AS "$BUSYBOX tee "$fix_extra_perms_script"" | egrep '(GIDERROR|UIDERROR)'
	measureEnd
	echo "$timingResult"
	measureResult "new createExtDataPermUpdateScript()"

	secondChecksum="`eval $AS "$BUSYBOX md5sum "$fix_extra_perms_script"" | awk '{print $1}'`"

	IFS="$OLDIFS"
	if [ "$firstChecksum" != "$secondChecksum" ] ; then
		echo "not equal $fix_extra_perms_script"
		echo "not equal $fix_extra_perms_scriptBak"
		echo "[Test Failed] restoreExtraDataTest"
	fi
	IFS="$OLDIFS"
}

setupTestData

restoreDataTest
restoreExtraDataTest

cleanupTestData
