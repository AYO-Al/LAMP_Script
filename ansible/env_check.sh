#!/bin/bash

if [ ! -e ./config.ini ];then
    echo "config.ini is not exists..please check.."
    exit 1
fi

HOSTS_IP=$(sed -n '/\[hosts\]/,/\[.*\]/p' config.ini | grep -v ^$ | grep -v "\[.*\]" | grep -v "^#" | awk '{print $1}')
ROOT_PASS=$(sed -n '/\[root_password\]/,/\[.*\]/p' config.ini | grep -v ^$ | grep -v "\[.*\]" | grep -v "^#")
OS_VERSION=$(sed -n '/\[os_version\]/,/\[.*\]/p' config.ini | grep -v ^$ | grep -v "\[.*\]" | grep -v "^#")
CPU_CORES=$(sed -n '/\[cpu_cores\]/,/\[.*\]/p' config.ini | grep -v ^$ | grep -v "\[.*\]" | grep -v "^#")
TIME_VALUE=$(sed -n '/\[time_sync_diff\]/,/\[.*\]/p' config.ini | grep -v ^$ | grep -v "\[.*\]" | grep -v "^#")

function verify_password
{
    if [ $# -lt 2 ];then
        echo "Usage: verify_password IP root_password"
        exit 1
    fi
    sshpass -p$2 ssh -o StrictHostKeyChecking=no root@$1 "df -h"
    if [ $? -ne 0 ];then
        echo "尝试通过SSH登录主机 $1 失败，请检查后重试脚本"
        return 255
    else
        return 0
    fi
}

function check_host_online
{
    echo "+++++++++++++++1、检查集群主机连通性++++++++++++++"
    for host in $HOSTS_IP;do
        ping -w 3 $host &> /dev/null
        if [ $? -eq 0 ];then
            echo "监测主机 $host 连通性通过"
        else
            echo "监测主机 $host 连通性失败，无法连通"
            ping_failed_hosts="$ping_failed_hosts $host"
        fi
    done

    if [[ "$ping_failed_hosts" == ""  ]];then
        echo "1.使用ping对集群主机连通性检查，全部通过！！！"
    else
        echo "1.使用ping对主机连通性检查。以下主机无法连通：$ping_failed_hosts"
        exit 1
    fi
}

function check_os_version
{
    echo "+++++++++++2、检查系统版本++++++++++++++++++++"
    for host in $HOSTS_IP;do
        verify_password $host $ROOT_PASS
        if [ $? -eq 0 ];then
            sshpass -p$ROOT_PASS ssh -o StrictHostKeyChecking=no root@$host "grep $OS_VERSION /etc/redhat-release" &> /dev/null
            if [ $? -ne 0 ];then
                echo "检查主机操作系统版本与目标($OS_VERSION)不一致，未通过"
                os_failed_hosts="$os_failed_hosts $host"
            else
                echo "检查主机操作系统版本与目标($OS_VERSION)一致，检查通过"
            fi
         else
                os_failed_hosts="$os_failed_hosts $host"
        fi
     done

     if [[ $os_failed_hosts == "" ]];then
         echo "2、检查主机操作系统版本与目标($OS_VERSION)一致性，全部通过"
     else
         echo "2、检查主机操作系统版本与目标($OS_VERSION)一致性，不通过。未通过主机为 $os_failed_hosts"
     fi
}

function check_cpu_cores
{
    echo "+++++++++++++++++++3、检查系统cpu个数++++++++++++++++"
    for host in $HOSTS_IP;do
        verify_password $host $ROOT_PASS
        if [ $? -eq 0 ];then
            DST_CPU_CORES=$(sshpass -p$ROOT_PASS ssh -o StrictHostKeyChecking=no root@$host "grep "^processor" /proc/cpuinfo |sort|uniq|wc -l")
            if [ $DST_CPU_CORES -lt $CPU_CORES ];then
                echo "检查主机CPU_CORES与目标($CPU_CORES)未通过"
                cpu_failed_hosts="$cpu_failed_hosts $host"
            else
                echo "检查主机CPU_CORES($CPU_CORES)，检查通过"
            fi
        else
            cpu_failed_hosts="$cpu_failed_hosts $host"
        fi
     done

     if [[ $cpu_failed_hosts == "" ]];then
         echo "3、检查主机CPU_CORES($CPU_CORES))全部通过"
     else
         echo "3、检查主机CPU_CORES不通过。未通过主机为 $cpu__failed_hosts"
     fi
}

function check_timesync
{
    echo "++++++++++++++++++4、检查集群主机时间++++++++++++++++++"
    for host in $HOSTS_IP;do
        LOCAL_TIME=`date "+%Y%m%d%H%M%S"`
        verify_password $host $ ROOT_PASS
        if [ $? -eq 0 ];then
            DST_HOST_TIME=$(sshpass -p$ROOT_PASS ssh 0o StrictHostKeyChecking=no root@$host 'date "+%Y%m%d%H%M%S"')
            TIME_DIFF=`expr $LOCAL_TIME - $DST_HOST_TIME`|sed 's/[^0-9]//g'
            if [ $TIME_DIFF -lt $TIME_VALUE ];then
                echo "检查主机 $host 时间同步通过"
            else
                echo "检查主机 $host 时间同步不通过。时间误差在$TIME_DIFF 秒"
                time_failed_hosts="$time_failed_hosts $host"
        
            fi
        else
            time_failed_hosts="$time_failed_hosts $host"
            echo no
        fi
    done

    if [[ $time_failed_hosts == "" ]];then
        echo ""4、检查集群主机时间是否同步，全部通过！！""
    else
        echo "4、检查集群主机时间是否同步，未通过，时间不同步的主机包括：$time_failed_hosts"
    fi
}
check_host_online
check_os_version
check_cpu_cores
check_timesync
