#!/bin/sh

/usr/sbin/rhn-search cleanindex && echo FSCK the db && /usr/bin/spacewalk-data-fsck -r -S -C -O
