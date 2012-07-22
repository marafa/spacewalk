#!/bin/sh

#this script will register this box (an already deployed server) with a spacewalk server

###variables
machine=`uname -m`
spacewalk=spacewalk.marafa.vm
ip=192.168.1.11
#os version
if [ -s /etc/centos-release ] 
then
	os=centos
	grep 6 /etc/centos-release > /dev/null && version=6 || version=5
else
	os=rhel
        grep 6 /etc/redhat-release > /dev/null && version=6 || version=5
fi

###main
 
#clean up before we start
yum clean all
yum -y erase rhn-org-trusted-ssl-cert-1.0-1.noarch

#assuming spacewalk fqdn is not in the dns
host $spacewalk > /dev/null 2>&1
[ $? -eq 0 ] || echo -e "$ip\tspacewalk $spacewalk" >> /etc/hosts

rpm -Uvh http://spacewalk.redhat.com/yum/1.7/RHEL/$version/$machine/spacewalk-client-repo-1.7-5.el$version.noarch.rpm

[ "$version" -eq "5" ] && rpm -Uvh http://dl.fedoraproject.org/pub/epel/$version/$machine/python-hashlib-20081119-4.el5.$machine.rpm || rpm -Uvh http://ftp.osuosl.org/pub/fedora-epel/6/i386/epel-release-6-7.noarch.rpm

#install rhn tools
yum -y install rhn-setup yum-rhn-plugin python-dmidecode yum-security.noarch python-hashlib

#install our cert
rpm -Uvh http://$spacewalk/pub/rhn-org-trusted-ssl-cert-1.0-1.noarch.rpm --force

#now that /etc/sysconfig/rhn/up2date exists, lets customise it
sed -i 's|sslCACert=/usr/share/rhn/RHNS-CA-CERT|sslCACert=/usr/share/rhn/RHN-ORG-TRUSTED-SSL-CERT|g' /etc/sysconfig/rhn/up2date 
sed -i 's|serverURL=.*$|serverURL=https://$spacewalk/XMLRPC|g' /etc/sysconfig/rhn/up2date

echo "`date` INFO: Registering with $spacewalk"
#activation key is calculate but is based on spacewalk-common-channels' ini file
rhnreg_ks --activationkey=1-$os$version-$machine --serverUrl=https://$spacewalk/XMLRPC --force

#we good?
rhn-channel -l > /dev/null
if [ $? -eq 0 ] 
then
#clean up old and duplicate repos
	rm -rf /etc/yum.repos.d/CentOS-*.repo
	rm -rf /etc/yum.repos.d/spacewalk-client*repo
fi
