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
# This script backs up data from $SOURCE to $PATHTOBACKUP using an
# optional file of exclusions referenced by $EXCLUDE_FROM.
# On every run, the script creates a directory $PATHTOBACKUP/${DATE}
# where ${DATE} is current date and time, so that every new backup
# is placed in its own directory. In addition to a directory with the backup
# the script can create
# ${DATE}.log.gz - log of the backup
# ${DATE}.err.gz - error log of the backup
# The script takes log file name as an optional parameter, see
# ./backups.sh -h
#
# Log files are gzipped and can be viewed with zcat and grepped with
# zgrep. Or those can also be ungzipped firs
#
# man zcat, man zgrep, man gunzip
#
# The script uses rsync and currently works only with local storage
# (an external drive which is attached directly to the computer).
#
# rsync creates hard links to those files which were not changed
# in the last back up.
#
# The current backup is referenced with soft link $PATHTOBACKUP/current
# The current backup log (if exists) is referenced with soft link
# $PATHTOBACKUP/current.log.gz
# The current backup error log (if exists) is referenced with soft link
# $PATHTOBACKUP/current.err.gz
#
# Before the script creates a backup, it may first execute ./clean-backups.sh
# if a corresponding argument is passed. See ./backup.sh -h
#
# See comments section at the top of clean-backups.sh to understand how it works
#

PATH=/usr/bin:/bin

d="`dirname $0`"
if [ "${d:0:1}" != "/" ] ; then
    # not absoulute path - prepend with `pwd`
    d="`pwd`/$d"
fi

EXCLUDE_FROM="$d/exclude.list"
SOURCE=/
PATHTOBACKUP=/mnt/backup/rpih
DATE=`date "+%Y-%m-%dT%H:%M:%S"`
CURRENT_PREFIX="current"
CLEAN_BACKUPS_SCRIPT="`dirname $0`/clean-backups.sh"

#
# $1 - log file name without extention
# $2 - log file extension
#
function gzipAndSoftLinkLog {
    filename=$1
    ext=$2
    logName=${filename}.${ext}

    rm -f ${CURRENT_PREFIX}.${ext}.gz

    #
    # if file exists and is not of zero size, create a softlink,
    # remove the file otherwise if it exists
    #
    if [ -s ${logName} ] ; then
        gzip ${logName}
        ln -s ${logName}.gz ${CURRENT_PREFIX}.${ext}.gz
    elif [ -f $logName ] ; then
        rm $logName
    fi
}

function announce() {
    echo
    echo "--- $* ---"
    echo
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
    echo "  -L          Output the log into the '$PATHTOBACKUP/${DATE}.log' and error to '$PATHTOBACKUP/${DATE}.err'"
    echo
    echo "  -c          Run clean-backups.sh first."
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
runCleanBackups=0
while getopts cdhl:L opt ; do
    case $opt in
        c) runCleanBackups=1 ;;
        d) destructiveRun=1 ;;
        l) logFile="$OPTARG" ;;
        L) logFile="$PATHTOBACKUP/$DATE" ;;
        h | ?) usage ; exit ;;
    esac
done
shift $(( OPTIND - 1 ));

if [ ! -d $PATHTOBACKUP -o ! -x $PATHTOBACKUP ] ; then
    echo "Error: Path to backup '$PATHTOBACKUP' either doesn't exist or the process doesn't have permissons to access it" >&2
    exit -1
fi

. `dirname $0`/common.sh

startTime=`date +"%s"`

if [ $runCleanBackups -eq 1 ] ; then
    if [ -x "$CLEAN_BACKUPS_SCRIPT" ] ; then
        args=
        if [ $destructiveRun -eq 1 ] ; then
            args+=" -d"
        fi
        if [ ! -z $logFile ] ; then
            args+=" -l $logFile"
        fi
        announce "Starting '$CLEAN_BACKUPS_SCRIPT $args'"
        "$CLEAN_BACKUPS_SCRIPT" $args
    else
        echo "Can not run $CLEAN_BACKUPS_SCRIPT - file does not exist"
        exit 1
    fi
fi

announce "Running backup"

mkdir -p $PATHTOBACKUP

pushd $PATHTOBACKUP > /dev/null

#
# construct options
#

opts=
# if there is a link to $CURRENT_PREFIX, then link-dest against it
if [ -L $PATHTOBACKUP/$CURRENT_PREFIX ] ; then
    opts+=" --link-dest=$PATHTOBACKUP/$CURRENT_PREFIX"
fi
# if exclusions file is defined, add it to the $opts
if [ -n $EXCLUDE_FROM ] ; then
    opts+=" --exclude-from=$EXCLUDE_FROM"
fi

#
# do rsync
#

rsync -av --stats $opts $SOURCE $PATHTOBACKUP/$DATE && \
    rsyncFailed=0 || \
    rsyncFailed=1

#
# log footer
#

endTime=`date +"%s"`

echo "------------------------------------------------------------"
if [ -n $EXCLUDE_FROM ] ; then
    echo "Used a list of exclusions from $EXCLUDE_FROM"
fi
echo "Finished in $(($endTime - $startTime)) seconds"

#
# Create links
#

if [ $rsyncFailed -eq 0 ] ; then
    ln -snf $DATE $CURRENT_PREFIX
else
    if [ ! -z $logFile ] ; then
        echo "Rsync failed. See ${logFile}.err.gz" >&2
    else
        echo "Rsync failed"
    fi
fi

if [ ! -z $logFile ] ; then
    gzipAndSoftLinkLog ${logFile} err
    gzipAndSoftLinkLog ${logFile} log
fi

popd > /dev/null
