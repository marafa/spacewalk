#!/bin/sh

yum upgrade ca-certificates --disablerepo=epel -y

yum -y install http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum -y install deltarpm yum-presto screen alpine git
yum -y install http://yum.spacewalkproject.org/2.2/RHEL/6/x86_64/spacewalk-repo-2.2-1.el6.noarch.rpm


yum -y install http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm deltarpm yum-presto screen alpine git http://yum.spacewalkproject.org/2.2/RHEL/6/x86_64/spacewalk-repo-2.2-1.el6.noarch.rpm

yum -y update

cd
if [ -d /root/bin ]
then
	cd /root/bin
	git update https://github.com/marafa/spacewalk.git
else
	git clone https://github.com/marafa/spacewalk.git bin
fi

if [ -d /root/spacewalk ]
then
	mv /root/spacewalk /root/bin
fi
cp /root/bin/jpackage*repo /etc/yum.repos.d/jpackage-generic.repo

##from https://fedorahosted.org/spacewalk/wiki/PostgreSQLServerSetup

yum install -y 'postgresql-server > 8.4'
yum install -y postgresql-pltcl

chkconfig postgresql on
service postgresql initdb
service postgresql start

su - postgres -c 'PGPASSWORD=spacepw; createdb -E UTF8 spaceschema ; createlang plpgsql spaceschema ; createlang pltclu spaceschema ; yes $PGPASSWORD | createuser -P -sDR spaceuser'

yum -y install spacewalk-setup-postgresql
yum -y install spacewalk-postgresql

cd /root/bin
export LANG=en_US.UTF-8
spacewalk-setup --disconnected --answer-file=spacewalk.answer

