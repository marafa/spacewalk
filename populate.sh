#!/bin/sh
### script to update the local spacewalk server
### if this is the first time, it will initialize the repo
### different strategies are used to populate each OS

variables(){
############################################
#begin variables section

debug=FALSE
dir=/local/rhn/
file=/tmp/spacewalk.rpms.lst
repo=/var/www/html/pub/repo

#spacewalk admin credentials
user=admin
password=password
#spacewalk version
spc_ver=`rpm -qv spacewalk-setup| sed 's/spacewalk-setup-//' | cut -d. -f1,2`
debug_msg spc_ver is $spc_ver
#client channel name
spc_client=`[ -f /usr/bin/spacewalk-common-channels ] && /usr/bin/spacewalk-common-channels -l | sort  | grep -v nightly | grep client-centos6 | tail -1 | awk '{print $1}'| sed 's/://'`
debug_msg spc_client is $spc_client

#get OS version
machine=`uname -m`
if [ -s /etc/centos-release ] 
then
        os=centos
else
        os=rhel
fi

version=`cat /etc/redhat-release | awk '{print $3}'| cut -d. -f1`
debug_msg version is $version

##### spacewalk client repo needed for rhn client packages
rpm=`rpm -qv spacewalk-client-repo`
rpm=$rpm.rpm
debug_msg spacewalk_client_repo rpm is $rpm
#end variables section
####################################################
}

preparation(){
#SELinux is to be disabled so Monitoring can work
/usr/sbin/setenforce 0
sed -i 's/=enforcing/=disabled/' /etc/selinux/config

echo `date` INFO: Refreshing RHN search index
time /etc/init.d/rhn-search cleanindex

echo `date` INFO: Clearing YUM cache
yum clean all
echo

if ! [ -f /var/www/html/pub/$rpm ]
then
        loc=http://yum.spacewalkproject.org/$spc_ver-client/RHEL/$version/$machine/
	echo " INFO: Downloading $loc$rpm"
        wget $loc$rpm --quiet -O /var/www/html/pub/$rpm > /dev/null 2>&1
fi

echo $rpm > /var/www/html/pub/client.txt

####################################################
# script dependencies
### program 1
rpm -q --whatprovides python-lxml || yum -y install python-lxml

###program 2
if ! [ -f /etc/yum.repos.d/spacewalk-client.repo ] 
then
	yum -y install spacewalk-client-repo
	yum -y update spacewalk-client-repo
fi

###program 3
[ -f /usr/bin/spacewalk-common-channels ] || yum -y install spacewalk-utils


###program 4
if ! [ -f /root/bin/centos-errata.py ]
then
	echo " WARN: /root/bin/rhn-clone-errata.py not found! "
	echo " INFO: Download from https://raw.github.com/unreality/Centos-Errata/a6a3ab101f07975f51c5b51b68ca4de789b98e15/centos-errata.py. Continuing"
fi
# end script dependencies
###################################################

### backup
if [ -e /etc/yum.repos.d/CentOS-Base.repo ] 
then
	mkdir /root/backups
	cp /etc/yum.repos.d/CentOS* /root/backups/
fi
}

cobbler(){ #experimenting
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

#list all kickstart distributions here
#ks_distro="$ks_distro centos$version-$machine"
ks_distro="$ks_distro centos5-x86_64"

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
#list all kickstart distributions here
ks_distro="$ks_distro centos6-x86_64"

echo "`date` INFO: Creating channels for CentOS 6"
/usr/bin/spacewalk-common-channels -u $user -p $password -a x86_64 'centos6*' spacewalk$spc_client-client-centos6-x86_64 -k unlimited
for id in centos6-x86_64 centos6-x86_64-addons centos6-x86_64-contrib centos6-x86_64-extras centos6-x86_64-fasttrack centos6-x86_64-centosplus centos6-x86_64-updates $spc_client-$machine
do
        echo "`date` INFO: Syncing Spacewalk repo to Spacewalk channel $id"
        time /usr/bin/spacewalk-repo-sync --channel=$id  #--type yum
done

echo "`date` INFO: Populating Errata for CentOS 6"
cd /root/bin > /dev/null
time /root/bin/centos-errata.py -l $user --password $password -f mail-archive.com --centos-version=6 -c /root/bin/centos6-errata.cfg
cd - > /dev/null
}

centos7(){
#list all kickstart distributions here
ks_distro="$ks_distro centos7-x86_64"

echo "`date` INFO: Creating channels for CentOS 7"
/usr/bin/spacewalk-common-channels -u $user -p $password -a x86_64 'centos7*' spacewalk$spc_client-client-centos7-x86_64 -k unlimited
for id in centos7-x86_64 centos7-x86_64-addons centos7-x86_64-contrib centos7-x86_64-extras centos7-x86_64-fasttrack centos7-x86_64-centosplus centos7-x86_64-updates $spc_client-$machine
do
        echo "`date` INFO: Syncing Spacewalk repo to Spacewalk channel $id"
        time /usr/bin/spacewalk-repo-sync --channel=$id  #--type yum
done

echo "`date` INFO: Populating Errata for CentOS 7"
cd /root/bin > /dev/null
time /root/bin/centos-errata.py -l $user --password $password -f mail-archive.com --centos-version=7 -c /root/bin/centos7-errata.cfg
cd - > /dev/null
}

spacewalk_client(){
id=$spc_client
echo ver = $spc_client
echo id = $id
echo channel= spacewalk20-client-centos6
echo "`date` INFO: Creating channel for $id"
echo /usr/bin/spacewalk-common-channels -u $user -p $password -a x86_64 $id -k unlimited
/usr/bin/spacewalk-common-channels -u $user -p $password -a x86_64 $id -k unlimited
echo "`date` INFO: Syncing Spacewalk repo to Spacewalk channel $id"
echo time /usr/bin/spacewalk-repo-sync --channel=$id  #--type yum
time /usr/bin/spacewalk-repo-sync --channel=$id  #--type yum
}

links(){
#script that will create a directory of symlinks for kickstart server.
echo
for distro in $ks_distro
do
	echo "`date` INFO: Creating repository for kickstart ($distro) at $repo/$distro/"
	rm -rf $repo/$distro
	mkdir -p $repo/$distro/Packages
	#centos 6 only !!!
	if [ -d /root/bin/images ]
	then 
		cp -r /root/bin/{images,isolinux,EFI} $repo/$distro/.
	else
		echo "`date` WARN: /root/bin/images missing. Skipping"
	fi
done

for pkg in `ls /var/satellite/redhat/1/*/*/*/*/*/*`
do 
        echo $pkg
done > $file

cat $file |sed 's/://g'| while read LINE
do
        echo $LINE|grep var > /dev/null
        if [ $? -eq 0 ] 
        then
                trg=$LINE
		link=`basename $LINE`
		debug_msg $LINE is a target link is $link 
        else
                link=$LINE
		debug_msg $LINE is a link
        fi
        ln -s $trg $repo/$distro/Packages/$link
	debug_msg ln -s $trg $repo/$distro/Packages/$link
done
}

repo(){
prefix=/usr/bin
if ! [ -e "$prefix/repoview" ] || ! [ -e "$prefix/createrepo" ]
#if ! [ -e /usr/bin/{repoview,createrepo} ] 
then
	echo " WARN: Either repoview or createrepo is not installed. Skipping"
	echo " WARN: Install with \"yum -y install createrepo repoview\""
else
for distro in $ks_distro
do
	! [ -d /var/www/html/pub/repoview ] || ln -s $repo/$distro/repoview /var/www/html/pub/repoview #personal: since i only have 1 disto
	echo "`date` INFO: Running createrepo on $repo/$distro"
	createrepo --database --pretty --update $repo/$distro > /tmp/populate.$distro.createrepo.log 2>&1
	echo "`date` INFO: Running repoview on $repo/$distro"
	repoview -t "YUM Repo: $distro" -u "http://`hostname`" -f $repo/$distro > /tmp/populate.$distro.repoview.log 2>&1
	echo "`date` INFO: Generating comps.xml in $repo/$distro"
	createrepo -g comps.xml $repo/$distro
done
fi
}

pub_dir(){ #contents of public dir /var/www/html/pub
if ! [ -f /var/www/html/pub/client.sh ]
then
	echo " INFO: Populating client.sh"
	mv /root/bin/client.sh /var/www/html/pub/client.sh
	ln -s /var/www/html/pub/client.sh /root/bin/client.sh
fi
}

debug(){
set -x
trap read debug
debug=TRUE
}

#########################################
# MAIN
#########################################

echo ============================
echo `date` `hostname`
echo ============================

lockfile=/var/tmp/populate.lck
#create lock file
if [ -e $lockfile ]
then
	echo " WARN: Lock file $lockfile exists. Is `basename $0` running?"
	exit 1
else
	touch $lockfile
fi

debug_msg(){
if [ debug == "TRUE" ] 
then
	echo Debug $*
fi
}

variables
#debug #do not use in batch mode
#debug=TRUE #enable this if u only want specific debug messages
preparation
#rhel5
#centos5
centos6
centos7
#spacewalk_client #in case we need to do this alone
#cobbler
#ks_distro="$ks_distro centos$version-$machine" #needed for procedure links or repo if run by itself
links
repo
pub_dir

#end
echo ============================
echo `date` `hostname`
rm -rf $lockfile #cleanup
cp -n /root/bin/spacewalk-populate.logrotate /etc/logrotate.d/spacewalk-populate
