#!/bin/bash
# Deploy a single file to an entire fleet and log progress
# v1.1 - clay michaels
#   added -p portal flag
# v1 - clay michaels 12 Oct 2015

while getopts ";d" opt
do
    case $opt in
        d) # Check if portal flag is set
            portal=true
            shift
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done

fleet=$1
file_to_send=$2
location=$3

log=/home/automation/scripts/clayScripts/dev/deployment_files/log_$1_$2.log

hosts=`cat /etc/hosts | grep $fleet | grep ^10. | tr -s ' ' | cut -d' ' -f2`
date=$(date)

if [ -f $log ] # log file exists
then
    already_done=`cat $log`
else
    touch $log
    already_done=""
fi

if ! [ -f $file_to_send ] # deployment file does not exist
then
    echo "Whoops! The file \"$file_to_send\" doesn't exist!"
    exit 1
fi


for host in $hosts
do
    echo -ne "CCU:$host"
    if [[ $already_done =~ $host ]]
    then
        echo " - Already done."
    else
        response=$(ping -c 1 $host)
        if [[ $response == *"100% packet loss"* ]]
        then
            echo " - Offline"
            continue
        else
            if [[ $portal == true ]]
            then
                output=`rsync --rsh='ssh -p8022' $file_to_send $host:$location 2>&1`
            else
                output=`rsync $file_to_send $host:$location 2>&1`
            fi
            if ! [ -z "$output" ]
            then
                useful_lines=`echo $output | grep -v "bind: Address already in use" | grep -v "channel_setup_fwd_listener: cannot listen to port" | grep -v "Could not request local forwarding"`
                useful_line_count=`echo $output | grep -v "bind: Address already in use" | grep -v "channel_setup_fwd_listener: cannot listen to port" | grep -v "Could not request local forwarding" | wc -l`
                if [[ $useful_line_count > 0 ]]
                then
                    echo "Error!"
                    echo $useful_lines
                    continue
                fi
            fi
            echo " - Done."
            echo "$date $host" >> $log
        fi
    fi
done
