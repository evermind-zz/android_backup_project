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
