#!/bin/sh
# populate.sh
#version 0.7
### script to update the local spacewalk server
###if this is the first time, it will initialize the repo
### different strategies are used to populate each OS

echo ============================
echo `date` `hostname`
echo ============================

dir=/local/rhn/
file=/tmp/spacewalk.rpms.lst
user=admin
password=password

if [ -s /etc/centos-release ] 
then
        os=centos
        grep 6 /etc/centos-release > /dev/null && version=6 || version=5
else
        os=rhel
        grep 6 /etc/redhat-release > /dev/null && version=6 || version=5
fi
repo=/var/www/html/repo/Packages

#SELinux is to be disabled so Monitoring can work
setenforce 0
sed -i 's/=enforcing/=disabled/' /etc/selinux/config

echo `date` INFO: Refreshing RHN search index
time /etc/init.d/rhn-search cleanindex

echo `date` INFO: Clearing YUM cache
yum clean all

rhel5(){
for id in rhel-x86_64-server-5 rhel-x86_64-server-vt-5 rhn-tools-x86_64-server-5 rhel-x86_64-server-fastrack-5 rhel-x86_64-server-cluster-storage-5 rhel-x86_64-server-cluster-5
do
        [ -d $dir/rhel/$id ] || mkdir -p $dir/rhel/$id

        echo "`date` INFO: Creating Channel $id"
        time /usr/bin/spacewalk-common-channels -u $user -p $password -a x86_64 $id -k unlimited -c /root/bin/rhel5_channels.ini
        echo "`date` INFO: Downloading RHN content for $id to $dir/$id"
        time /usr/bin/reposync -p $dir --repoid=$id -l -n -d
        echo "`date` INFO: Creating local repo for $id"
        time /usr/bin/createrepo $dir/$id
        echo "`date` INFO: Syncing Spacewalk repo $id to Spacewalk channel"
        time /usr/bin/spacewalk-repo-sync --channel=$id
        echo "`date` INFO: Downloading Errata for Channel $id"
        time /root/bin/rhn-clone-errata.py --login=$user --password=$password -s localhost --src-channel=$id --publish --verbose
done
}

centos5(){
echo "`date` INFO: Creating channels for CentOS 5"
/usr/bin/spacewalk-common-channels -u $user -p $password -a x86_64 'centos5*' -k unlimited
for id in centos5-x86_64 centos5-x86_64-addons centos5-x86_64-contrib centos5-x86_64-extras centos5-x86_64-fasttrack centos5-x86_64-centosplus centos5-x86_64-updates
do
        echo "`date` INFO: Syncing Spacewalk repo to Spacewalk channel $id"
        time /usr/bin/spacewalk-repo-sync --channel=$id  #--type yum
done

echo "`date` INFO: Populating Errata for CentOS 5"
cd /root/bin
time /root/bin/centos-errata.py -l $user --password $password -f mail-archive.com --centos-version=5 -c /root/bin/centos5-errata.cfg
cd -
}

centos6(){
echo "`date` INFO: Creating channels for CentOS 6"
/usr/bin/spacewalk-common-channels -u $user -p $password -a x86_64 'centos6*' spacewalk17-client-centos6 -k unlimited
for id in centos6-x86_64 centos6-x86_64-addons centos6-x86_64-contrib centos6-x86_64-extras centos6-x86_64-fasttrack centos6-x86_64-centosplus centos6-x86_64-updates spacewalk17-client-centos6
do
        echo "`date` INFO: Syncing Spacewalk repo to Spacewalk channel $id"
        time /usr/bin/spacewalk-repo-sync --channel=$id  #--type yum
done

echo "`date` INFO: Populating Errata for CentOS 6"
cd /root/bin
time /root/bin/centos-errata.py -l $user --password $password -f mail-archive.com --centos-version=6 -c /root/bin/centos6-errata.cfg
cd -
}

repo(){
#script that will create a directory of links for kickstart server.
echo "`date` INFO: Creating repository for kickstart"

[ -d $repo ] && rm -rf $repo/* || mkdir $repo

for pkg in `ls /var/satellite/redhat/1/*/*/*/*/*`
do 
        echo $pkg
done > $file

cat $file |sed 's/://g'| while read LINE
do
        echo $LINE|grep var > /dev/null
        if [ $? -eq 0 ] 
        then
                trg=$LINE
        else
                link=$LINE
                ln -s $trg $repo/$link
        fi
done
}

#rhel5
#centos5
centos6

repo

echo ============================
echo `date` `hostname`
