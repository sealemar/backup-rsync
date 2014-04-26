# redirect logs to appropriate files
logFileLog="${logFile}.log"
logFileErr="${logFile}.err"
if [ ! -z $logFile ] ; then
    1>&-
    touch "$logFileLog" || {
        echo "The process doesn't have permissions to create a file $logFileLog" >&2
        exit -1
    } && exec 1>> "$logFileLog"
    2>&-
    touch "$logFileErr" || {
        echo "The process doesn't have permissions to create a file $logFileErr"
        exit -1
    } && exec 2>> "${logFileErr}"
fi
