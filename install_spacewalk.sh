#!/bin/sh

do_yum(){
	
yum clean all
yum -y upgrade ca-certificates --disablerepo=epel

#yum -y install http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm deltarpm yum-presto screen alpine git http://yum.spacewalkproject.org/2.2/RHEL/6/x86_64/spacewalk-repo-2.2-1.el6.noarch.rpm createrepo repoview
yum -y install epel-release deltarpm yum-presto screen alpine git createrepo repoview http://yum.spacewalkproject.org/2.4/RHEL/7/x86_64/spacewalk-repo-2.4-3.el7.noarch.rpm

yum -y update
}

do_git(){
cd
if [ -d /root/bin ]
then
	cd /root/bin
	git pull https://github.com/marafa/spacewalk.git
else
	git clone https://github.com/marafa/spacewalk.git bin
fi

if [ -d /root/spacewalk ]
then
	mv /root/spacewalk /root/bin
fi
cp /root/bin/jpackage*repo /etc/yum.repos.d/jpackage-generic.repo
}

hmm(){ #is this necessary
##from https://fedorahosted.org/spacewalk/wiki/PostgreSQLServerSetup
yum install -y 'postgresql-server > 8.4'
yum install -y postgresql-pltcl

chkconfig postgresql on
service postgresql initdb
service postgresql start

su - postgres -c 'PGPASSWORD=spacepw; createdb -E UTF8 spaceschema ; createlang plpgsql spaceschema ; createlang pltclu spaceschema ; yes $PGPASSWORD | createuser -P -sDR spaceuser'
}

do_firewall(){
service iptables stop
chkconfig iptables off
}

do_postgresql(){
yum -y install spacewalk-setup-postgresql
yum -y install spacewalk-postgresql
}

do_locale(){
#set locale
localedef -v -c -i en_US -f UTF-8 en_US.UTF-8
export LANG=en_US.UTF-8
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
#
sed -i 's,LANG=.*,LANG="en_US.UTF-8",g' /etc/sysconfig/i18n
}

#prepare OS
do_yum
do_git
do_locale
do_firewall
do_postgresql

cd /root/bin
spacewalk-setup --disconnected --answer-file=spacewalk.answer
