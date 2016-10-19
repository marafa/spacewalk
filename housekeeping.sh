#!/bin/sh

/usr/sbin/rhn-search cleanindex && /usr/bin/spacewalk-data-fsck -r -S -C -O
