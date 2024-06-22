#!/bin/bash


HOST_LIST="172.16.100.40 172.16.100.50 172.16.100.60"
STATUS_CMD="jps | grep -w Kafka"
START_CMD="/opt/source/kafka/bin/kafka-server-start.sh -daemon /opt/source/kafka/config/server.properties"
STOP_CMD="/opt/source/kafka/bin/kafka-server-stop.sh"
SERVICE_NAME="kafka broker"

function service_start
{
    for host in $HOST_LIST;do
        echo "-------NOW begin To Start Kafka In Host : $host-----------------"
        service_status $host
        if [ $? -eq 0 ];then
            echo "Kafka broker in $host is already RUNNING"
        else
            echo "Now $SERVICE_NAME is STOPPED,Start it...."
            ssh -o StrictHostKeyChecking=no $host $START_CMD &> /dev/null
            index=0
            while [ $index -lt 5 ];do
                service_status $host
                if [ $? -ne 0 ];then
                    index=`expr $index + 1`
                    echo "$index Times:Kafka broker in $host is start failed..Please wait.."
                    echo "After 3 seconds will check kafka status agein.."
                    sleep 3
                    continue
                else
                    echo "OK...Kafka broker in $host is RUNNING.."
                    break
                fi
            done
            if [ $index -eq 5 ];then
                echo "Sorry...Kafka broker Start Failed..Please login $host to check"
            fi
        fi
    done
}


function service_stop
{
    for host in $HOST_LIST;do
        echo "-------NOW begin To Stop Kafka In Host : $host-----------------"
        service_status $host
        if [ $? -ne 0 ];then
            echo "Kafka broker in $host is already STOPPED"
        else
            echo "Now kafka broker is RUNNING,Start it...."
            ssh -o StrictHostKeyChecking=no $host $STOP_CMD &> /dev/null
            index=0
            while [ $index -lt 5 ];do
                service_status $host
                if [ $? -eq 0 ];then
                    index=`expr $index + 1`
                    echo "$index Times:Kafka broker in $host is stopping..Please wait.."
                    echo "After 3 seconds will check kafka status agein.."
                    sleep 3
                    continue
                else
                    echo "OK...Kafka broker in $host is STOPPED now.."
                    break
                fi
            done
            if [ $index -eq 5 ];then
                echo "Sorry...Kafka broker Stop Failed..Please login $host to check"
            fi
        fi
    done
}


function service_status
{
   status_idx=0
   result=0
   while [ $status_idx -lt 5 ];do
        ssh -o StrictHostKeyChecking=no $1 $STATUS_CMD &> /dev/null
        if [ $? -eq 0 ];then
            result=`expr $status_idx + 1 `
        fi
        status_idx=`expr $status_idx + 1 `
   done
   if [ $result -eq 3 ];then
       return
   fi
   return 99
}

function usage
{
cat << EOF
Usage 1: sh $0 start   #Start Kafka Process Define IN Host_LIST
Usage 2: sh $0 stop    #Stop Kafka Process Define IN Host_LIST
Usage 3: sh $0 status  #GET Kafka Status Define IN Host_LIST
EOF
}

case $1 in 
    start)
        service_start
        ;;
    stop)
        service_stop
        ;;
    status)
        for host in $HOST_LIST;do
               echo "--------------------NOE Begin To Detect Kafka Status In Host: $host------------------"
               service_status $host
               if [ $? -eq 0 ];then
                   echo "Kafka broker in $host is RUNNING"
               else
                   echo "Kafka broker in $host is STOPPED"
               fi
        done
        ;;
    *)
        usage
        ;;
esac
