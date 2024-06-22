#!/bin/bash

if [ $# -lt 2 ];then
	echo "Usage: sh $0 user_name user_pass"
	exit 1
fi

ROOT_PASS="root"
USER_NAME=$1
USER_PASS=$2
HOST_LIST="172.16.100.40 172.16.100.50 172.16.100.60"

# 管理主机本地创建用户、设置密码
useradd $USER_NAME
echo $USER_PASS | passwd --stdin $USER_NAME

# 管理主机生成秘钥对
su - $USER_NAME -c "echo "" | ssh-keygen -t rsa"
PUB_KEY="`cat /home/$USER_NAME/.ssh/id_rsa.pub`"


# 在所有主机创建用户
# 利用非免密初始化免密
for host in $HOST_LIST;do
	sshpass -p$ROOT_PASS ssh -o StrictHostKeyChecking=no root@$host "useradd $USER_NAME"
	sshpass -p$ROOT_PASS ssh -o StrictHostKeyChecking=no root@$host "echo $USER_PASS | passwd --stdin $USER_NAME"
	sshpass -p$ROOT_PASS ssh -o StrictHostKeyChecking=no root@$host "mkdir /home/$USER_NAME/.ssh -pv"
	sshpass -p$ROOT_PASS ssh -o StrictHostKeyChecking=no root@$host "echo $PUB_KEY> /home/$USER_NAME/.ssh/authorized_keys"
	sshpass -p$ROOT_PASS ssh -o StrictHostKeyChecking=no root@$host "chmod 600 /home/$USER_NAME/.ssh/authorized_keys"
	sshpass -p$ROOT_PASS ssh -o StrictHostKeyChecking=no root@$host "chown -R $USER_NAME:$USERNAME /home/$USER_NAME/.ssh"
done
