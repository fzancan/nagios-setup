#!/bin/bash

# Check for root
if [ $EUID -ne 0 ]; then
    echo "You must be root to run this program."
    exit 1
fi


# Check if system type is ubuntu
SYSTEM=$(uname -a)
grep -iq ubuntu <<<$SYSTEM
if [ $? -ne 0 ]; then
    echo "This script can run safely only on Ubuntu systems."
    exit 1
fi

# https://www.digitalocean.com/community/tutorials/how-to-install-nagios-4-and-monitor-your-servers-on-ubuntu-14-04

# Prepare installation
apt-get update

apt install mysql-server
apt install apache2
apt install php7.0 libapache2-mod-php7.0
apt install postfix

useradd nagios
groupadd nagcmd
usermod -a -G nagcmd nagios

apt-get install build-essential libgd2-xpm-dev openssl libssl-dev xinetd apache2-utils unzip


# Install Nagios core
cd ~
curl -L -O https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.3.2.tar.gz
tar xvf nagios-*.tar.gz
cd nagios-*
./configure --with-nagios-group=nagios --with-command-group=nagcmd --with-mail=/usr/sbin/sendmail
make all
make install
make install-commandmode
make install-init
make install-config
/usr/bin/install -c -m 644 sample-config/httpd.conf /etc/apache2/sites-available/nagios.conf


# Install Nagios Plugins
cd ~
curl -L -O http://nagios-plugins.org/download/nagios-plugins-2.2.1.tar.gz
tar xvf nagios-plugins-*.tar.gz
cd nagios-plugins-*

./configure --with-nagios-user=nagios --with-nagios-group=nagios --with-openssl
make
make install

# Install NRPE
cd ~
curl -L -O https://sourceforge.net/projects/nagios/files/nrpe-2.x/nrpe-2.15/nrpe-2.15.tar.gz
tar xvf nrpe-*.tar.gz
cd nrpe-*
./configure --enable-command-args --with-nagios-user=nagios --with-nagios-group=nagios --with-ssl=/usr/bin/openssl --with-ssl-lib=/usr/lib/x86_64-linux-gnu

make all
make install
make install-xinetd
make install-daemon-config

# Use this instead of 'vi /etc/xinetd.d/nrpe' to add current IP address to the only_from clause
IP=$(hostname -I)
cat /etc/xinetd.d/nrpe | sed "s/\(^.*only_from\s*=\s*127\.0\.0\.1\).*$/\1 $IP/" | tee /etc/xinetd.d/nrpe
service xinetd restart

# Nagios is now installed, we need to configure it.

vi /usr/local/nagios/etc/nagios.cfg
cat /usr/local/nagios/etc/nagios.cfg | sed "s/#\(cfg_dir=\/usr\/local\/nagios\/etc\/servers\)/\1/" | tee /usr/local/nagios/etc/nagios.cfg

mkdir /usr/local/nagios/etc/servers

# TODO: parametrize admin email contact
ADMIN_EMAIL="federico@emailchef.com"
cat /usr/local/nagios/etc/objects/contacts.cfg | sed "s/\(^.*email\s*\)nagios@localhost\(.*$\)/\1$ADMIN_EMAIL\2/" | tee /usr/local/nagios/etc/objects/contacts.cfg

printf "\ndefine command{\n    command_name check_nrpe\n    command_line \$USER1$/check_nrpe -H \$HOSTADDRESS$ -c \$ARG1$\n}" > /usr/local/nagios/etc/objects/commands.cfg 
