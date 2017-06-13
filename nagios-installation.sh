#!/bin/bash

# Check if system type is ubuntu
SYSTEM=$(uname -a)
grep -iq ubuntu <<<$SYSTEM
if [ $? -ne 0 ]; then
    echo "This script can run safely only on Ubuntu systems."
    exit 1
fi

# https://www.digitalocean.com/community/tutorials/how-to-install-nagios-4-and-monitor-your-servers-on-ubuntu-14-04

# Prepare installation
sudo apt-get update

sudo apt install mysql-server
sudo apt install apache2
sudo apt install php7.0 libapache2-mod-php7.0
sudo apt install postfix

sudo useradd nagios
sudo groupadd nagcmd
sudo usermod -a -G nagcmd nagios

sudo apt-get install build-essential libgd2-xpm-dev openssl libssl-dev xinetd apache2-utils unzip


# Install Nagios core
cd ~
curl -L -O https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.3.2.tar.gz
tar xvf nagios-*.tar.gz
cd nagios-*
./configure --with-nagios-group=nagios --with-command-group=nagcmd --with-mail=/usr/sbin/sendmail
make all
sudo make install
sudo make install-commandmode
sudo make install-init
sudo make install-config
sudo /usr/bin/install -c -m 644 sample-config/httpd.conf /etc/apache2/sites-available/nagios.conf


# Install Nagios Plugins
cd ~
curl -L -O http://nagios-plugins.org/download/nagios-plugins-2.2.1.tar.gz
tar xvf nagios-plugins-*.tar.gz
cd nagios-plugins-*

./configure --with-nagios-user=nagios --with-nagios-group=nagios --with-openssl
make
sudo make install

# Install NRPE
cd ~
curl -L -O https://sourceforge.net/projects/nagios/files/nrpe-2.x/nrpe-2.15/nrpe-2.15.tar.gz
tar xvf nrpe-*.tar.gz
cd nrpe-*
./configure --enable-command-args --with-nagios-user=nagios --with-nagios-group=nagios --with-ssl=/usr/bin/openssl --with-ssl-lib=/usr/lib/x86_64-linux-gnu

make all
sudo make install
sudo make install-xinetd
sudo make install-daemon-config

# Use this instead of 'sudo vi /etc/xinetd.d/nrpe' to add current IP address to the only_from clause
IP=$(hostname -I)
cat /etc/xinetd.d/nrpe | sed "s/\(^.*only_from\s*=\s*127\.0\.0\.1\).*$/\1 $IP/" | sudo tee /etc/xinetd.d/nrpe
sudo service xinetd restart

# Nagios is now installed, we need to configure it.


