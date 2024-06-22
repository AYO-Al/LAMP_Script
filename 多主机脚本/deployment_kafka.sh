#!/bin/bash

# 命令报错退出脚本
set -e

HOST_LIST="172.16.100.40 172.16.100.50 172.16.100.60"
LOCAL_DIR="/opt/tmp"
PACKAGE_DIR="/opt/package"
APP_DIR="/opt/source"
JDK_NAME="jdk-8u212-linux-x64.tar.gz"
CMD_NUM=0
ZK_NAME="apache-zookeeper-3.7.0-bin.tar.gz"
SCALA_NAME="scala-2.12.11.tgz"
KAFKA_NAME="kafka_2.12-2.6.1.tgz"

# 使用exec指令定义日志
if [ -e ./deployment_kafka.log ];then
	rm -rf ./deployment_kafka.log
fi
exec 1>>./deploy_kafka.log 2>&1

# 封装多主机执行指令
function remote_execute
{
	for host in $HOST_LIST;do
		CMD_NUM=`expr $CMD_NUM + 1`
        echo "+++++++++++++++++++++++++Execute Command < $@  > ON Host: $host++++++++++++++++++++++++"
        ssh -o StrictHostKeyChecking=no root@$host $@
		if [ $? -eq 0 ];then
			echo "Congratulation Command < $@ > execute success"
		else
			echo "Sorry Command < $@ > execute failed"
		fi
	done
}

# 多主机传输文件函数封装
function remotr_transfer
{
    SRC_FILE=$1
    DST_DIR=$2
    if [ $# -lt 2];then
       echo "USAGE: $0 <file|dir> <des_dir> "
       exit 1
    fi
    
    # 判断第一个参数是否存在
    if [ ! -e $SRC_FILE ];then
        echo "ERROR - $SRC_FILE is not exist,Please check..."
        exit 1
    fi 

    # 判断第二个参数是否存在
    for host in $HOST_LIST;do
        echo "++++++++++++++Transfer File To Host: $host++++++++++++++++++"
        CMD_NUM=$(($CMD_NUM+1))
        scp -o StrictHostKeyChecking=no $SRC_FILE  root@$host:"if [ ! -e $DST_DIR ];then mkdir -p $DST_DIR;else echo $DST_DIR"
        scp -o StrictHostKeyChecking=no $SRC_FILE  root@$host:$DST_DIR/
        if [ $? -eq 0 ];then
            echo "Remote Host: $host - $CMD_NUM -INFO - scp $SRC_FILE To dir $DST_DIR Success"
        else
            echo "Remote Host: $host - $CMD_NUM -INFO - scp $SRC_FILE To dir $DST_DIR Failed"
        fi
    done
    
}

remote_execute "df -h"
# 关闭firewall和selinux
remote_execute "systemctl stop firewalld"
remote_execute "systemctl disable firewalld"
remote_execute "setenforce 0"
remote_execute "sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux"


# 安装配置JDK
remotr_transfer $LOCAL_DIR/$JDK_NAME $PACKAGE_DIR
remote_execute "if [ ! -d $APP_DIR ];then mkdir -p $APP_DIR;fi"
remote_execute "tar -zxvf $PACKAGE_DIR/$JDK_NAME -C $APP_DIR"

cat > $LOCAL_DIR/java.sh << EOF
export JAVA_HOME=$APP_DIR/jdk1.8.0_212
export PATH=\$PATH:\$JAVA_HOME/bin:\$JAVA_HOME/jre/bin
export SJAVA_HOME PATH
EOF

remotr_transfer $LOCAL_DIR/java.sh /etc/profile.d/
remote_execute "source /etc/profile.d/java.sh"
remote_execute "java -version"


# 安装配置zookeeper，并启动服务
remotr_transfer $LOCAL_DIR/$ZK_NAME $PACKAGE_DIR
remote_execute "tar -zxvf $PACKAGE_DIR/$ZK_ANEM -C $APP_DIR -C $APP_DIR"
remote_execute "if [ ! -e $APP_DIR/zookeeper ];then rm -rf $APP_DIR/zookeeper;fi"
remote_execute "ln -sv $APP_DIR/apache-zookeeper-3.7.0-bin $APP_DIR/zookeeper"

remote_execute "cp $APP_DIR/zookeeper/conf/zoo_sample.cfg $APP_DIR/zookeeper/conf/zoo.cfg"

cat > $LOCAL_DIR/zoo_tmp.conf << EOF
server.1=172.16.100.40:2888:3888
server.2=172.16.100.50:2888:3888
server.3=172.16.100.60:2888:3888
EOF

remotr_transfer $LOCAL_DIR/zoo_tmp.conf /tmp
remote_execute "cat /tmp/zoo_tmp.conf >> $APP_DIR/zookeeper/conf/zoo.cfg"

remote_execute "if [ -e /data/zk ];then rm -rf /data/zk;fi"
remote_execute "mkdir /data/zk -p"
remote_execute "sed -i 's/dataDir=\/tmp\/zookeeper/dataDir=\/data\/zk/g' $APP_DIR/zookeeper/conf/zoo.cfg"

remote_execute 'if [ `hostname` == "node01" ];then echo 1 > /data/zk/myid;fi'
remote_execute 'if [ `hostname` == "node02" ];then echo 2 > /data/zk/myid;fi'
remote_execute 'if [ `hostname` == "node03" ];then echo 3 > /data/zk/myid;fi'

remote_execute 'jps | grep QuorumPeerMain | grep -v grep | awk '{print $1}' > /tmp/zk.pid'
remote_execute 'if [ -s /tmp/zk.pid ];then kill -9 `cat /tmp/zk.pid`;fi'
remote_execute "$APP_DIR/zookeeper/bin/zkServer.sh start"

# 安装配置scala环境
remotr_transfer $LOCAL_DIR/$SCALA_NAME $PACKAGE_DIR
remote_execute "tar -zxvf $PACKAGE_DIR/$SCALA_NAME -C $APP_DIR"

cat > $LOCAL_DIR/scala.sh << EOF
export SCALA_HOME=$APP_DIR/scala-2.12.11
export PATH=\$PATH:\$SCALA_HOME/bin
export SSCALA_HOME PATH
EOF

remotr_transfer $LOCAL_DIR/scala.sh /etc/profile.d/
remote_execute "source /etc/profile.d/scala.sh"
remote_execute "scala -version"

# 安装配置kafka，并启动服务
remotr_transfer $LOCAL_DIR/$KAFKA_NAME $PACKAGE_DIR
remote_execute "tar -zxvf $PACKAGE_DIR/$KAFKA_NAME -C $APP_DIR"

remote_execute "if [ -e $APP_DIR/kafka ];then rm -rf $APP_DIR/kafka;fi"
remote_execute "ln -sv $APP_DIR/$KAFKA_NAME $APP_DIR/kafka"
remote_execute "if [ -e /data/kafka/log ];then rm -rf /data/kafka/log;fi"
remote_execute "mkdir -p /data/kafka/log"

remote_execute "sed -i '/zookeeper.connect=localhost:2181/d' $APP_DIR/kafka/config/server.properties"
remote_execute "sed -i '\$azookeeper.connect=172.16.100.40:2181 172.16.100.50:2181 172.16.100.60:2181' $APP_DIR/kafka/config/server.properties"

remote_execute 'if [ `hostname` =="node01" ];then sed -i 's/broker.id=0/broker.id=100/g' $APP_DIR/kafka/config/server.properties;fi'
remote_execute 'if [ `hostname` =="node02" ];then sed -i 's/broker.id=0/broker.id=200/g' $APP_DIR/kafka/config/server.properties;fi'
remote_execute 'if [ `hostname` =="node03" ];then sed -i 's/broker.id=0/broker.id=300/g' $APP_DIR/kafka/config/server.properties;fi'

remote_execute 'if [ `hostname` =="node01" ];then sed -i '$alisteners=PLAINTEXT://172.16.100.40:9092' $APP_DIR/kafka/config/server.properties;fi'
remote_execute 'if [ `hostname` =="node02" ];then sed -i '$alisteners=PLAINTEXT://172.16.100.50:9092' $APP_DIR/kafka/config/server.properties;fi'
remote_execute 'if [ `hostname` =="node03" ];then sed -i '$alisteners=PLAINTEXT://172.16.100.60:9092' $APP_DIR/kafka/config/server.properties;fi'

remote_execute "sed -i 's/log.dirs=\/tmp\/kafka0logs/log.dirs=\/data\/kafka\/log/g' $APP_DIR/kafka/config/server.properties"

remote_execute "jps | grep Kafka | grep -v grep | awk '{print \$1}' > /tmp/kafka.pid"
remote_execute "if [ -s /tmp/kafka.pid ];then kill -9 \`cat /tmp/kafka.pid\`;fi"

remote_execute "$APP_DIR/kafka/bin/kafka-server-start.sh $APP_DIR/kafka/config/server.properties"

sleep 30

remote_execute 'if [ `hostname` == "node01" ];then $APP_DIR/kafka/bin/kafka-topics.sh --zookeeper localhost --create --topic test --partitions 5 --replication-factor 2;fi'

sleep 5
remote_execute 'if [ `hostname` == "node01" ];then $APP_DIR/kafka/bin/kafka-topics.sh --zookeeper localhost --topic test --describe;fi'

