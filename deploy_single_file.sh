#!/bin/bash
# Deploy a single file to an entire fleet and log progress
# v1.2.3 - Clay Michaels 29 Feb 2016
#   Added -s option to skip output for Already Done
# v1.2.2 - Clay Michaels 25 Feb 2016
#   Added progress numbers e.g. "4/12 done"
#   Known bug (found by Jason Chong) - acela.1 and .2 trigger "already done"
#       Based on acela.1[0-9] and acela.2[0-1]
#       RESOLVED: changed /etc/hosts to put "acela.ts02" before "acela.2"
# v1.2.1 - Clay Michaels 23 Feb 2016
#   updated file paths after moving out of /dev
#   removed "CCU:" at the beginning of each output line
# v1.2 - Clay michaels 18 Nov 2015
#   added -r flag to resume
#   changed log format to include the fleet,file,location at the top
# v1.1 - clay michaels
#   added -p portal flag
# v1 - clay michaels 12 Oct 2015

while getopts ":dsr:" opt
do
    case $opt in
        d) # "Portal" - deploy to portals
            portal=true
            shift
            ;;
        r) # "Resume" - resume previous deployment
            resume=true
            resume_log=$OPTARG
            ;;
        s) # "Silence" - skip "Already Done" option
            silent=true
            ;;
        \?)
            this_script=`basename "$0"`
            echo "Invalid option: -$OPTARG" >&2
            echo "Expected one of the following patterns:"
            echo "$this_script <fleet> <file> <deployment path>"
            echo "$this_script -r <existing log file to resume>"
            exit 1
            ;;
    esac
done

#############################
# Trying to parse fleet, file, location from input
if [ "$resume" = true ]
then
    # resuming
    if [ -e $resume_log ]
    then
        echo "resuming $resume_log"
        log=$resume_log
        fleet="`head -n3 $resume_log | sed -n 1p`"
        file_to_send="`head -n3 $resume_log | sed -n 2p`"
        location="`head -n3 $resume_log | sed -n 3p`"
        echo "Fleet    =$fleet"
        echo "File     =$file_to_send"
        echo "Location =$location"
        already_done=`cat $log`
    else
        # resuming, but log does not exist
        echo "Input file does not exist!"
        exit 1
    fi
else
    # Starting a new deployment (not resuming)
    echo "Starting new deployment:"
    fleet=$1
    file_to_send=$2
    file_to_send_printable=${file_to_send##*/}
    location=$3
    log="/home/automation/scripts/clayScripts/deployment_files/${fleet}_${file_to_send_printable}.log"
    echo "Fleet    =$fleet"
    echo "File     =$file_to_send"
    echo "Location =$location"
    echo "Log file =$log"
    echo "$fleet" > $log
    echo "$file_to_send" >> $log
    echo "$location" >> $log
    already_done=""
fi

if ! [ -f $file_to_send ] # deployment file does not exist
then
    echo "Whoops! The file \"$file_to_send\" doesn't exist!"
    exit 1
fi





hosts=`cat /etc/hosts | grep $fleet | grep -vi "bench" | grep ^10. | tr -s ' ' | cut -d' ' -f2`
date=$(date)

success_count=0
total_count=0
for host in $hosts
do
    ((total_count++))
    if [[ $already_done =~ $host ]]
    then
        if [[ $silent != true ]]
        then
            echo "$host - Already done."
        fi
        ((success_count++))
    else
        response=$(ping -c 1 $host)
        if [[ $response == *"100% packet loss"* ]]
        then
            echo "$host - Offline"
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
            echo "$host - Done."
            echo "$date $host" >> $log
            ((success_count++))
        fi
    fi
done

echo "Status: $success_count/$total_count"
