#!/bin/sh
#license is GPL or BSD. up to you

#this script will register this box (an already deployed server) with a spacewalk server
version=0.7
###variables
bits=`uname -m`
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
if [ -f /usr/share/rhn/RHN-ORG-TRUSTED-SSL-CERT ]
then
	yum -y erase rhn-org-trusted-ssl-cert-1.0-1.noarch
fi

#assuming spacewalk fqdn is not in the dns
grep spacewalk /etc/hosts > /dev/null 2>&1
if ! [ $? -eq 0 ]
then
        echo -e "$ip\t$spacewalk spacewalk" >> /etc/hosts
fi

#install spacewalk client repo
rpm -Uvh http://$spacewalk/pub/spacewalk-client-repo-1.9-1.el6.noarch.rpm 
                                                                                                                                                                        
[ "$version" -eq "5" ] && rpm -Uvh http://dl.fedoraproject.org/pub/epel/$version/$bits/python-hashlib-20081119-4.el5.$bits.rpm || rpm -Uvh http://$spacewalk/pub/epel-release-6-8.noarch.rpm

#install our cert
rpm -Uvh http://$spacewalk/pub/rhn-org-trusted-ssl-cert-1.0-1.noarch.rpm --force

#install rhn tools - to avoid "ERROR: can not find RHNS CA file"
yum -y install rhn-setup yum-rhn-plugin python-dmidecode yum-plugin-security.noarch python-hashlib

#now that /etc/sysconfig/rhn/up2date exists, lets customise it
if [ -f /etc/sysconfig/rhn/up2date ]
then
	sed -i 's|sslCACert=/usr/share/rhn/RHNS-CA-CERT|sslCACert=/usr/share/rhn/RHN-ORG-TRUSTED-SSL-CERT|g' /etc/sysconfig/rhn/up2date
	sed -i 's|serverURL=.*$|serverURL=https://$spacewalk/XMLRPC|g' /etc/sysconfig/rhn/up2date
else
	echo " ERROR! /etc/sysconfig/rhn/up2date not found. Unable to continue!"
	exit
fi

echo "`date` INFO: Registering with $spacewalk"
#activation key is calculated but is based on spacewalk-common-channels' ini file
rhnreg_ks --activationkey=1-$os$version-$bits --serverUrl=https://$spacewalk/XMLRPC --force

#are we good?
rhn-channel -l > /dev/null
if [ $? -eq 0 ]
then
	echo " INFO: `hostname` is now registered with $spacewalk"
	#clean up old and duplicate repos
	echo " INFO: Cleaning up old and/or duplicate repos"
	rm -rf /etc/yum.repos.d/CentOS*repo #no enable= line in these repos. deleting instead
	yum -y erase spacewalk-client-repo epel-release
else
	echo " ERROR: Registeration with $spacewalk failed. Pls. check logs"
fi
