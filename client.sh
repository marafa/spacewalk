#!/bin/sh

#this script will register this box (an already deployed server) with a spacewalk server

###variables
machine=`uname -m`
spacewalk=spacewalk.vm.desktop.us
ip=192.168.1.11

if [ -s /etc/centos-release ] 
then
	os=centos
	grep 6 /etc/centos-release > /dev/null && version=6 || version=5
else
	os=rhel
        grep 6 /etc/redhat-release > /dev/null && version=6 || version=5
fi

###main
 
yum clean all
yum -y erase rhn-org-trusted-ssl-cert-1.0-1.noarch

#assuming spacewalk fqdn is not in the dns
grep $spacewalk /etc/hosts > /dev/null 2>&1
[ $? -eq 0 ] || echo -e "$ip\tspacewalk $spacewalk" >> /etc/hosts

rpm -Uvh http://spacewalk.redhat.com/yum/1.7/RHEL/$version/$machine/spacewalk-client-repo-1.7-5.el$version.noarch.rpm

[ "$version" -eq "5" ] && rpm -Uvh http://dl.fedoraproject.org/pub/epel/$version/$machine/python-hashlib-20081119-4.el5.$machine.rpm

echo yum -y install rhn-setup yum-rhn-plugin python-dmidecode yum-security.noarch python-hashlib

rpm -Uvh http://$spacewalk/pub/rhn-org-trusted-ssl-cert-1.0-1.noarch.rpm --force

rm -rf /etc/yum.repos.d/CentOS-*.repo

sed -i 's|sslCACert=/usr/share/rhn/RHNS-CA-CERT|sslCACert=/usr/share/rhn/RHN-ORG-TRUSTED-SSL-CERT|g' /etc/sysconfig/rhn/up2date 
sed -i 's|serverURL=.*$|serverURL=https://$spacewalk/XMLRPC|g' /etc/sysconfig/rhn/up2date

echo "`date` INFO: Registering with $spacewalk"
#activation key is calculate but is based on spacewalk-common-channels' ini file
rhnreg_ks --activationkey=1-$os$version-$machine --serverUrl=https://$spacewalk/XMLRPC --force
