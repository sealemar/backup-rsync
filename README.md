backup-rsync
============

Backup utility

## ./backups.sh
---------------

This script backs up data from $SOURCE to $PATHTOBACKUP using an
optional file of exclusions referenced by $EXCLUDE_FROM.
On every run, the script creates a directory $PATHTOBACKUP/${DATE}
where ${DATE} is current date and time, so that every new backup
is placed in its own directory. In addition to a directory with the backup
the script can create
${DATE}.log.gz - log of the backup
${DATE}.err.gz - error log of the backup
The script takes log file name as an optional parameter, see
**./backups.sh -h**

Log files are gzipped and can be viewed with zcat and grepped with
zgrep. Or those can also be ungzipped firs

man zcat, man zgrep, man gunzip

The script uses rsync and currently works only with local storage
(an external drive which is attached directly to the computer).

rsync creates hard links to those files which were not changed
in the last back up.

The current backup is referenced with soft link $PATHTOBACKUP/current
The current backup log (if exists) is referenced with soft link
$PATHTOBACKUP/current.log.gz
The current backup error log (if exists) is referenced with soft link
$PATHTOBACKUP/current.err.gz

Before the script creates a backup, it may first execute ./clean-backups.sh
if a corresponding argument is passed. See **./backup.sh -h**

See comments section at the top of clean-backups.sh to understand how it works


## ./clean-backups.sh
---------------------

This script makes an attempt to remove
old backups which meet certain criteria (see below). It makes an
attempt only if the script starting time is later than $MILESTONE. This is
done to protect from sporadic backup deletions if system clock is
not set or corrupted (i.e. Raspberry Pi doesn't have an RTC module.
In this situation, when the system is started, the time is set to
the beginning of Unix Epoch)

Backup preservations criterias:

* All daily backups from the two past weeks are preserved
* All weekly backups up to 20 weeks are preserved (Sunday backups)
* All monthly backups are preserved (the last backup of a month)

All other backups are moved to trash. Those backups which were moved
to trash are preserved there for 30 days. If a backup wasn't reclaimed
(moved outside the trash), it is deleted.

This script prints the report (see _printReport()_)

By default the script doesn't delete anything, but outputs which backup
directories it would delete if it were to run without that option.
To do a destructive run - actually deleting bacup directories, run
the script with option "-d"

See **./clean-backups.sh -h** for more options.


## ./exclude.list
-----------------

A good to go **exclude.list** is included. To understand the format, see
**man rsync** section _Include/Exclude Pattern Rules_, or go to
[man rsync online](http://linux.die.net/man/1/rsync)
