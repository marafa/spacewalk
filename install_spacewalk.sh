#!/bin/sh

yum -y install http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum -y install deltarpm yum-presto screen alpine git
yum -y install http://yum.spacewalkproject.org/2.2/RHEL/6/x86_64/spacewalk-repo-2.2-1.el6.noarch.rpm
yum -y update

cd
git https://github.com/marafa/spacewalk.git
mv /root/spacewalk /root/bin
cp /root/bin/jpackage*repo /etc/yum.repos.d/jpackage-generic.repo
yum -y install spacewalk-setup-postgresql
yum -y install spacewalk-postgresql
cd /root/bin
spacewalk-setup --disconnected --answer-file=spacewalk.answer

