#!/bin/sh
# populate.sh
#version 0.8
### script to update the local spacewalk server
### if this is the first time, it will initialize the repo
### different strategies are used to populate each OS

echo ============================
echo `date` `hostname`
echo ============================

dir=/local/rhn/
file=/tmp/spacewalk.rpms.lst
repo=/var/www/html/repo
#spacewalk admin credentials
user=admin
password=password
#spacewalk version
#spc_ver=19
spc_ver=`rpm -qi spacewalk-client-repo|grep Version| awk '{print $3}'|sed 's/\.//g'`

#get version
machine=`uname -m`
if [ -s /etc/centos-release ] 
then
        os=centos
        grep 6 /etc/centos-release > /dev/null && version=6 || version=5
else
        os=rhel
        grep 6 /etc/redhat-release > /dev/null && version=6 || version=5
fi

#list all kickstart distributions here
#ks_distro=CentOS-6.2-x86_64 
ks_distro="centos$version-$machine"

preparation(){
#SELinux is to be disabled so Monitoring can work
/usr/sbin/setenforce 0
sed -i 's/=enforcing/=disabled/' /etc/selinux/config

echo `date` INFO: Refreshing RHN search index
time /etc/init.d/rhn-search cleanindex

echo `date` INFO: Clearing YUM cache
yum clean all
echo

if ! [ -f /var/www/html/pub/spacewalk-client-repo-1.9-1.el6.noarch.rpm ]
then
	echo " INFO: Downloading Spacewalk Client Repo"
	cd /var/www/html/pub
	wget http://yum.spacewalkproject.org/1.9-client/RHEL/6/x86_64/spacewalk-client-repo-1.9-1.el6.noarch.rpm 
	cd -
fi
}

cobbler(){
[ -d /var/satellite/rhn/kickstart ] || mkdir -p /var/satellite/rhn/kickstart
chown apache.root /var/satellite/rhn/kickstart 
}

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
/usr/bin/spacewalk-common-channels -u $user -p $password -a x86_64 'centos6*' spacewalk$spc_ver-client-centos6-x86_64 -k unlimited
for id in centos6-x86_64 centos6-x86_64-addons centos6-x86_64-contrib centos6-x86_64-extras centos6-x86_64-fasttrack centos6-x86_64-centosplus centos6-x86_64-updates spacewalk$spc_ver-client-centos6-x86_64
do
        echo "`date` INFO: Syncing Spacewalk repo to Spacewalk channel $id"
        time /usr/bin/spacewalk-repo-sync --channel=$id  #--type yum
done

echo "`date` INFO: Populating Errata for CentOS 6"
cd /root/bin > /dev/null
time /root/bin/centos-errata.py -l $user --password $password -f mail-archive.com --centos-version=6 -c /root/bin/centos6-errata.cfg
cd - > /dev/null
}

spacewalk_client(){
id=spacewalk$spc_ver-client-centos6-x86_64
echo "`date` INFO: Creating channel for $id"
/usr/bin/spacewalk-common-channels -u $user -p $password -a x86_64 $id -k unlimited
echo "`date` INFO: Syncing Spacewalk repo to Spacewalk channel $id"
time /usr/bin/spacewalk-repo-sync --channel=$id  #--type yum
}

links(){
#script that will create a directory of symlinks for kickstart server.
echo
for distro in $ks_distro
do
	echo "`date` INFO: Creating repository for kickstart ($distro)"
	rm -rf $repo/$distro
	mkdir -p $repo/$distro/Packages
	cp -r /root/bin/{images,isolinux,EFI} $repo/$distro/.
done

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
                ln -s $trg $repo/$distro/Packages/$link
        fi
done
}

repo(){
for distro in $ks_distro
do
	[ -d /var/www/html/repoview ] || ln -s $repo/$distro/repoview /var/www/html/repoview #personal: since i only have 1 disto
	echo "`date` INFO: Running createrepo on $repo/$distro"
	createrepo --database --pretty --update $repo/$distro > /tmp/populate.$distro.createrepo.log 2>&1
	echo "`date` INFO: Running repoview on $repo/$distro"
	repoview -t "YUM Repo: $distro" -u "http://`hostname`" -f $repo/$distro > /tmp/populate.$distro.repoview.log 2>&1
done
}

preparation
#rhel5
#centos5
centos6
#spacewalk_client #in case we need to do this alone
cobbler
links
repo

echo ============================
echo `date` `hostname`
