#!/bin/bash

# Func:Get Process Status In process.cfg

# Define Variables
HOME_DIR="/root/shell_b/script"
FILE_NAME=process.cfg

function get_all_group
{
	G_LIST=$(sed -n '/\[GROUP_LIST\]/,/\[.*\]/p' $HOME_DIR/$FILE_NAME | grep -v ^$|grep -v "\[*\]")
	echo "$G_LIST"
}

function get_all_process
{
	for g in `get_all_group`
	do
		p_list=$(sed -n "/\[$g\]/,/\[.*\]/p" $HOME_DIR/$FILE_NAME | grep -v ^$|grep -v "\[*\]")
		echo "$p_list"
	done
}

function get_process_pid_by_name
{
	if [ $# -ne 1 ];then
		return 1
	else
		pids=`ps -ef | grep $1 | grep -v grep | grep -v $$ |awk '{print $2}'` 
		echo "$pids"
	fi
}

function get_process_info_by_pid
{	
	if [ `ps -ef | awk -v pid=$1 '$2==pid{print }' | wc -l` -eq 1 ];then	
		pro_staus="RUNNING"
	else
		pro_staus="STOPED"
	fi
	pro_cpu=`ps aux | awk -v pid=$1 '$2==pid{print $3}'`
	pro_mem=`ps aux | awk -v pid=$1 '$2==pid{print $4}'`
	pro_start_time=`ps -p $1 -o lstart | grep -v STARTED`
}

function is_group_in_config
{
	for gn in `get_all_group`;do
		if [ "$gn" == "$1" ];then
			return 
		fi
	done
	echo "GroupName $1 is not in process.cfg"
	return 1
}


function get_all_precess_by_group
{
	is_group_in_config $1
	if [ $? -eq 0  ];then
		p_list=$(sed -n "/\[$1\]/,/\[.*\]/p" $HOME_DIR/$FILE_NAME | grep -v ^$|grep -v "\[*\]")
		echo $p_list
	else
		echo "Process $1 is not in process.cfg"
	fi 	
}

function get_group_by_process_name
{
	for gn in `get_all_group`;do
		for pn in `get_all_precess_by_group $gn`;do
			if [ $pn == $1 ];then
				echo "$gn"
			fi
		done
	done
}

function format_print
{
	ps -ef | grep $1 |grep -v grep |grep -v $$ &> /dev/null
	if [ $? -eq 0 ];then
		pids=`get_process_pid_by_name $1`
		for pid in $pids;do
			get_process_info_by_pid $pid
			awk -v p_name=$1 \
			-v g_name=$2 \
			-v p_status=$pro_staus \
			-v p_pid=$pid\
			-v p_cpu=$pro_cpu \
			-v p_mem=$pro_mem \
			-v p_start_time="$pro_start_time" \
			'BEGIN{printf "%-10s%-10s%-10s%-5s%-5s%-5s%-15s\n",p_name,g_name,p_status,p_pid,p_cpu,p_mem,p_start_time}'
		done
	else
		awk -v p_name=$1 \
                    -v g_name=$2 \
                        'BEGIN{printf "%-10s%-10s%-10s%-5s%-5s%-5s%-15s\n",p_name,g_name,"NULL","NULL","NULL","NULL","NULL"}'

	fi
}




function is_process_in_config
{
	for pn in `get_all_process`;do
		if [ $pn == $1 ];then
			return 
		fi
	done
	echo "Process $1 not in process.cfg"
	return 1
}

awk 'BEGIN{printf "%-10s%-10s%-10s%-5s%-5s%-5s%-15s\n","pname","gname","status","pid","cpu","mem","start_time"}'

if [ $# -gt 0  ];then
	if [ "$1" == "-g" ];then
		shift
		for gn in $@;do
			is_group_in_config $gn || continue
			for pn in `get_all_precess_by_group $gn`;do
				is_process_in_config $pn && format_print $pn $gn
			done
		done
	else
		for pn in $@;do
			gn=`get_group_by_process_name $pn`
			is_process_in_config $pn && format_print $pn $gn
		done
	fi
	echo
else
	for pn in `get_all_process`;do
		gn=`get_group_by_process_name $pn`
     	        is_process_in_config $pn && format_print $pn $gn

	done
fi

if [ ! -e $HOME_DIR/$FILE_NAME ];then
        echo "$FILE_NAME is not exit..Please Check.."
	exit 1
fi 
