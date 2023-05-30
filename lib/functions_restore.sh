function createDataPermUpdateScript() {
    local workDir="$1"
    local oldGid="$2"
    local newGid="$3"
    local oldUid="$4"
    local newUid="$5"
    local oldGidVar=$(($oldGid + 10000))
    local newGidVar=$(($newGid + 10000))

    local re='OLDU=([0-9]+):OLDG=([0-9]+):FILENAME=(.*)'
    local cmd="chown"

    echo "# dataDir: oldGid=$oldGid newGid=$newGid oldUid=$oldUid newUid=$newUid oldGidVar=$oldGidVar newGidVar=$newGidVar"

    eval $AS "$BUSYBOX find $workDir ! -type l -exec $BUSYBOX stat -c \"OLDU=%u:OLDG=%g:FILENAME=%n\" {} +" \
    | while read line ; do
        [[ $line =~ $re ]]
        OLDU=${BASH_REMATCH[1]}
        OLDG=${BASH_REMATCH[2]}
        FILE=${BASH_REMATCH[3]}
        FILE="${FILE//\"/\\\"}"

        edebug "# oldOwner $cmd $OLDU:$OLDG \"$FILE\""
        edebug "OLDU=$OLDU OLDG=$OLDG"

        # replace gid
        local nGid="$OLDG"
        if [ "$OLDG" -ne "$oldGid" ] ; then
            # test if we have special GidVar
            if [ "$OLDG" -eq "$oldGidVar" ] ; then
                # replace $oldGidVar with newGidVar
                nGid="$newGidVar"
                #echo "$OLDG" -eq "$oldGidVar"
            elif [ "$OLDG" -eq "0" ] ; then # keep do nothing eg lib dir is root only
                nGid="0"
            else
                echo "GIDERROR $cmd $OLDU:$OLDG \"$FILE\""
                exit 1
            fi
        else
            nGid=$newGid
        fi

        # replace uid
        local nUid="$OLDU"
        if [ "$OLDU" -eq "$oldUid" ] ; then
            nUid="$newUid"
        elif [ "$OLDG" -eq "0" ] ; then # keep do nothing eg lib dir is root only
            nUid="0"
        else
            echo "UIDERROR $cmd $OLDU:$OLDG \"$FILE\""
            exit 1
        fi

        echo "$cmd $nUid:$nGid \"$FILE\""
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

    local re='OLDU=([0-9]+):OLDG=([0-9]+):FILENAME=(.*)'
    local cmd="chown"

    echo "# extDataDir: oldGid=$oldGid newGid=$newGid oldGidVar=$oldGidVar newGidVar=$newGidVar"

    eval $AS "$BUSYBOX find $workDir ! -type l -exec $BUSYBOX stat -c \"OLDU=%u:OLDG=%g:FILENAME=%n\" {} +" \
    | while read line ; do
        [[ $line =~ $re ]]
        OLDU=${BASH_REMATCH[1]}
        OLDG=${BASH_REMATCH[2]}
        FILE=${BASH_REMATCH[3]}
        FILE="${FILE//\"/\\\"}"
        local preText=""

        edebug "# oldOwner $cmd $OLDU:$OLDG \"$FILE\""
        edebug "OLDU=$OLDU OLDG=$OLDG"

        # replace gid
        local nGid="$OLDG"
        if [ "$OLDG" -ne "$media_rw" ] ; then
            # test if we have special GidVar
            if [ "$OLDG" -eq "$oldGidVar" ] ; then
                # replace $oldGidVar with newGidVar
                nGid="$newGidVar"
            elif [ "$OLDG" -eq "$oldGidVar2" ] ; then
                # replace $oldGidVar2 with newGidVar2
                nGid="$newGidVar2"
            else
                echo "GIDERROR $cmd OLDU=$OLDU:OLDG=$OLDG \"$FILE\""
                exit 1
            fi
        else
            nGid=$media_rw
            preText="# skip as same perms "
        fi

        # no need to replace uid as it should be $media_rw
        # -> just prepare $line executable
        if [ "$OLDU" -eq "$media_rw" ] ; then
            nUid="$media_rw"
        else
            echo "UIDERROR $cmd $OLDU:$OLDG \"$FILE\""
            exit 1
        fi

        echo "${preText}$cmd $nUid:$nGid \"$FILE\""
    done
}
