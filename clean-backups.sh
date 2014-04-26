#!/bin/sh

#
# Copyright 2014 Sergey Markelov
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# This script makes an attempt to remove
# old backups which meet certain criteria (see below). It makes an
# attempt only if the script starting time is later than $MILESTONE. This is
# done to protect from sporadic backup deletions if system clock is
# not set or corrupted (i.e. Raspberry Pi doesn't have an RTC module.
# In this situation, when the system is started, the time is set to
# the beginning of Unix Epoch)
#
# Backup preservations criterias:
#
# *) All daily backups from the two past weeks are preserved
# *) All weekly backups up to 20 weeks are preserved (Sunday backups)
# *) All monthly backups are preserved (the last backup of a month)
#
# All other backups are moved to trash. Those backups which were moved
# to trash are preserved there for 30 days. If a backup wasn't reclaimed
# (moved outside the trash), it is deleted.
#
# This script prints the report (see printReport())
#
# By default the script doesn't delete anything, but outputs which backup
# directories it would delete if it were to run without that option.
#
# To do a destructive run - actually deleting bacup directories, run
# the script with option "-d"
#
# See ./clean-backups.sh -h for more options.
#

PATH=/usr/bin:/bin

MILESTONE=1384198772
PATHTOBACKUP=/mnt/backup/rpih
TRASH="${PATHTOBACKUP}/trash"
TRASH_DB="${TRASH}/trash.db"

PRESERVE_DAILY=14
PRESERVE_WEEKLY=20
# which weekly backup to preserver ([0..6]: 0 - Sunday)
PRESERVE_WEEKLY_DAY_NUMBER=0

SECS_IN_DAY=86400
SECS_IN_WEEK=$(($SECS_IN_DAY * 7))
PRESERVE_DAILY_SECS=$(($PRESERVE_DAILY * $SECS_IN_DAY))
PRESERVE_WEEKLY_SECS=$(($PRESERVE_WEEKLY * $SECS_IN_WEEK))

# timestamp when a backup is moved to trash is saved
# if the backup is not reclaimed (moved outside the trash)
# until (BACKUP_TRASH_TIME + RECLAIM_PERIOD_SECS) then
# it is removed from the trash.
# Note, that when a backup is removed from the trash,
# it is gone.
RECLAIM_PERIOD_SECS=$((30 * $SECS_IN_DAY))

now=`date +"%s"`

destructiveRun=0

backupsMoved=0
totalBackups=0
function moveBackupsToTrash {
    backupsMoved=0
    totalBackups=0
    for dir in `find . -maxdepth 1 -type d -name '20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]' | sed 's,\./\(.\+\),\1,' | tr '\n' ' '` ; do
        totalBackups=$(($totalBackups + 1))
        backupTimestamp=`date -d "$dir" +"%s"`
        dif=$(($now - $backupTimestamp))
        deleteBackup=0
        reason="N/A"

        # $dif > $PRESERVE_DAILY_SECS
        if [ $dif -gt $PRESERVE_DAILY_SECS ] ; then
            # $PRESERVE_WEEKLY_DAY_NUMBER != dayofweek($dir)
            if [ $PRESERVE_WEEKLY_DAY_NUMBER -ne `date -d "$dir" +"%w"` ] ; then
                reason="Not a Sunday backup"
                echo -n "$reason - "
                deleteBackup=1
            # $dif > $PRESERVE_WEEKLY_SECS
            elif [ $dif -gt $PRESERVE_WEEKLY_SECS ] ; then
                # dayofmonth($dir) > 7 => not the first backup of a month => delete it
                if [ `date -d "$dir" +"%d"` -lt 25 ] ; then
                    reason="Not the last backup of a month"
                    echo -n "$reason - "
                    deleteBackup=1
                fi
            fi
        fi

        if [ $deleteBackup -eq 1 ] ; then
            echo "$PATHTOBACKUP/$dir"
            if [ $destructiveRun -eq 1 ] ; then
                mv "$PATHTOBACKUP/$dir"* "${TRASH}/"
                echo "$now $dir $reason" >> "${TRASH_DB}"
            fi
            backupsMoved=$(($backupsMoved + 1))
        fi
    done
}

backupsCleaned=0
backupsInTrash=0
function cleanTrash {
    backupsInTrash=`ls -1 | wc -l`
    backupsCleaned=0
    sed '/^#/d' "${TRASH_DB}" | while read -r timestamp backupDir reason ; do
        if [ $(($timestamp + $RECLAIM_PERIOD_SECS)) -le $now ] ; then
            echo -n "Removing backup - $backupDir - trashed on '`date -d "@$timestamp" +"%c"`'"
            if [ $destructiveRun -eq 1 ] ; then
                removeEntry=0
                if [ -d "${TRASH}/${backupDir}" ] ; then
                    rm -fr "${TRASH}/${backupDir}"* && {
                        echo " - done"
                        backupsCleaned=$(($backupsCleaned + 1))
                        removeEntry=1
                    } || \
                    echo " - failed"
                else
                    echo " - dir doesn't exist"
                    removeEntry=1
                fi

                # remove the corresponding entry from TRASH_DB
                if [ $removeEntry -eq 1 ] ; then
                    sed -i "/$backupDir/d" "${TRASH_DB}"
                fi
            else
                echo
            fi
        fi
    done
}

function printReport {
    echo
    echo "Path to backups    : ${PATHTOBACKUP}"
    echo "Trash location     : ${TRASH}"
    echo "Backups count      : $totalBackups"
    echo "Moved to trash     : $backupsMoved"
    echo "Backups in trash   : $backupsInTrash"
    echo "Cleaned from trash : $backupsCleaned"
}

function usage() {
    echo "Usage: `basename $0` [ arg, ... ]"
    echo
    echo "  -d          Destructive run. By default dry run is used. The report is printed in the end,"
    echo "              but no harm is actually dun"
    echo
    echo "  -l filename  Output the log into the filename."
    echo "               Note: that will create two files [ filename.log and filename.err ]"
    echo
    echo "  -h          Show this help"
    echo
    echo "   This is the part of backup utility"
    echo " Note: read the comment section at the bottom of the script"
}

#
# main
#
logFile=
while getopts l:dh opt ; do
    case $opt in
        l) logFile="$OPTARG" ;;
        d) destructiveRun=1 ;;
        h | ?) usage ; exit ;;
    esac
done
shift $(( OPTIND - 1 ));

. `dirname $0`/common.sh

ret=0

if [ $now -gt $MILESTONE ] ; then
    if [ -d $PATHTOBACKUP -a -x $PATHTOBACKUP ] ; then
        pushd $PATHTOBACKUP > /dev/null

        if [ $destructiveRun -eq 1 ] ; then
            mkdir -p "$TRASH"
            if [ ! -s "$TRASH_DB" ] ; then
                echo "# timestamp directory reason" > "${TRASH_DB}"
            fi
        fi

        moveBackupsToTrash
        cleanTrash
        printReport

        popd > /dev/null
    else
        echo "Error: Path to backup '$PATHTOBACKUP' either doesn't exist or the process doesn't have permissons to access it" >&2
        ret=1
    fi
else
    echo "Error: now < MILESTONE. now = $now, MILESTONE = ${MILESTONE}. now - MILESTONE = $(($now - $MILESTONE))" >&2
    ret=1
fi

if [ -f "$logFileLog" -a ! -s "$logFileLog" ] ; then
    rm "$logFileLog"
fi
if [ -f "$logFileErr" -a ! -s "$logFileErr" ] ; then
    rm "$logFileErr"
fi

exit $ret
