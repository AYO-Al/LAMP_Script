#!/bin/bash
# 初始化
systemctl stop firewalld && systemctl disable firewalld
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0
systemctl start chronyd
read -p "需要设置自己的时间服务器嘛(y/n)：" y
if [[ $y = "y" ]];then
    read -p "请输入你的时间服务器IP：" c_ip
    sed -i 's/server/\#server/' /etc/chrony.conf 
    echo "server $c_ip iburst" >> /etc/chrony.conf
    sed -i "s/^#allow.*$/allow/g" /etc/chrony.conf
    sed -i "s/^#local.*$/local stratum 10/g" /etc/chrony.conf
fi
echo "初始化成功！！！"

# YUM源
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum install -y epel-release
echo "YUM源设置成功！！！"

# 配置HTTPD和PHP
yum install -y httpd mod_ssl php-fpm php-mysql mariadb-server php-mbstring expect
if [ ! -d "/var/www/html/phpadmin" ];then
wget --no-check-certificate https://files.phpmyadmin.net/phpMyAdmin/4.4.15/phpMyAdmin-4.4.15-all-languages.tar.xz
tar -xvf phpMyAdmin-4.4.15-all-languages.tar.xz -C /var/www/html/ 
mv /var/www/html/phpMyAdmin-4.4.15-all-languages /var/www/html/phpadmin
fi

cat > /var/www/html/index.php << EOF
<?php
phpinfo();
?>
EOF

cat > /etc/httpd/conf.d/https.conf << EOF
<VirtualHost *:80>
    #DocumentRoot /var/www/asite
    ServerName www.admin.com
    Redirect temp / https://$(ifconfig ens33 | grep -o 'inet [0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' | awk '{print $2}')
</VirtualHost>

<VirtualHost *:443>
    DocumentRoot /var/www/html
    DirectoryIndex index.php
    ServerName www.admin.com
    SSLEngine on
    SSLCertificateFile /etc/pki/tls/certs/localhost.crt
    SSLCertificateKeyFile /etc/pki/tls/private/localhost.key

    # 添加其他HTTPS相关配置
</VirtualHost>
EOF

cat > /etc/httpd/conf.d/php.conf << EOF
DirectoryIndex index.php
ProxyRequests off
ProxyPassMatch "^/.*\.php(.*)$" "fcgi://127.0.0.1:9000/var/www/html/"
EOF

mkdir /var/lib/php/session && chown apache.apache /var/lib/php/session
systemctl restart httpd php-fpm
echo "HTTPS and PHP 设置成功！！！"


# 初始化数据库
systemctl start mariadb
read -p "请输出你的数据库密码：" my_pass
expect << EOF
spawn mysql -uroot -p
expect "password" { send "\n"; }
expect "MariaDB" { send "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$my_pass');\n" } 

expect eof
EOF
echo "数据库初始化成功！！！"
