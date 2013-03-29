#!/bin/sh
user=admin
password=password

echo "Creating EPEL6 channel"
date
time /usr/bin/spacewalk-common-channels -u $user -p $password -a x86_64 epel6 -k unlimited
/usr/bin/spacewalk-repo-sync --channel=epel6-centos6-x86_64 -i python-argparse -i python-migrate -i python-novaclient -i python-kombu -i python-boto -i python-iso8601 -i python-amqplib -i python-warlock -i python-httplib2 -i python-httplib2 -i python-anyjson -i python-prettytable -i python-quantumclient -i python-prettytable -i python-keystone* -i python-swift* -i python-cinder* -i python-quantum* -i python-nova*  -i python-cmd2 -i python-tablib -i libyaml -iopenstack* -inovnc -i pysendfile* -i Django14* -ipython-django-* -ipysendfile*

#htop
/usr/bin/spacewalk-repo-sync --channel=epel6-centos6-x86_64 -i htop -i koan -i python-hwdata
