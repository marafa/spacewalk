#!/bin/sh
#license is GPL or BSD. up to you
#this script will register this box (an already deployed server) with a spacewalk server

###variables
bits=`uname -m`
fqdn=spacewalk.cloud.egit
ip=10.200.1.9 

#os version
[ "grep Linux /etc/redhat-release" ] && version=`cat /etc/redhat-release | awk '{print $4}'| cut -d. -f1` || version=`cat /etc/redhat-release | awk '{print $3}'| cut -d. -f1`
debug_msg version is $version

#get OS version
machine=`uname -m`
if [ -s /etc/centos-release ] 
then
        os=centos
else
        os=rhel
fi

###main
 
#clean up before we start
yum clean all
if [ -f  /etc/yum.repos.d/epel.repo ]
then
	yum -y upgrade ca-certificates --disablerepo=epel
else
	yum -y upgrade ca-certificates
fi

if [ -f /usr/share/rhn/RHN-ORG-TRUSTED-SSL-CERT ]
then
	yum -y erase rhn-org-trusted-ssl-cert-1.0-1.noarch
fi

rpm -q --whatprovides epel-release || epel=epel-release

#assuming spacewalk fqdn is not in the dns
grep $fqdn /etc/hosts > /dev/null 2>&1
if ! [ $? -eq 0 ]
then
        echo -e "$ip\t$fqdn spacewalk" >> /etc/hosts
fi

#install spacewalk client repo
curl http://$fqdn/pub/client.txt > ./client.txt
rpm=`cat client.txt`
rm -rf client.txt
rpm -Uvh http://$fqdn/pub/$rpm
yum -y update $rpm
                                                                                                                                                                        
[ "$version" -eq "5" ] && rpm -Uvh http://dl.fedoraproject.org/pub/epel/$version/$bits/python-hashlib-20081119-4.el5.$bits.rpm || rpm -Uvh http://$fqdn/pub/epel-release-6-8.noarch.rpm

#install our cert
rpm -Uvh http://$fqdn/pub/rhn-org-trusted-ssl-cert-1.0-1.noarch.rpm --force

#install rhn tools - to avoid "ERROR: can not find RHNS CA file"
yum -y install epel-release
yum -y install rhn-setup yum-rhn-plugin python-dmidecode yum-plugin-security.noarch python-hashlib yum-presto deltarpm 

#now that /etc/sysconfig/rhn/up2date exists, lets customise it
if [ -f /etc/sysconfig/rhn/up2date ]
then
	sed -i 's|sslCACert=/usr/share/rhn/RHNS-CA-CERT|sslCACert=/usr/share/rhn/RHN-ORG-TRUSTED-SSL-CERT|g' /etc/sysconfig/rhn/up2date
	sed -i 's|serverURL=.*$|serverURL=https://$fqdn/XMLRPC|g' /etc/sysconfig/rhn/up2date
else
	echo " ERROR! /etc/sysconfig/rhn/up2date not found. Unable to continue!"
	exit 1
fi

echo "`date` INFO: Registering with $fqdn"
#activation key is calculated but is based on spacewalk-common-channels' ini file
rhnreg_ks --activationkey=1-$os$version-$bits --serverUrl=https://$fqdn/XMLRPC --force

#are we good?
rhn-channel -l > /dev/null
if [ $? -eq 0 ]
then
	echo " INFO: `hostname` is now registered with $fqdn"
	#clean up old and duplicate repos
	echo " INFO: Cleaning up old and/or duplicate repos"
	rm -rf /etc/yum.repos.d/CentOS*repo #no enable= line in these repos. deleting instead
	#the following are no longer required and therefore erased
	yum -y erase spacewalk-client-repo $epel
	yum clean all
else
	echo " ERROR: Registration with $fqdn failed. Pls. check logs"
fi
