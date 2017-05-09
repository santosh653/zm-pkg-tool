#!/bin/bash

if [ -f /etc/redhat-release ]
then
   ( cd /tmp/local-repo && createrepo /tmp/local-repo/zmb-store/D1/ )
   ( cd /tmp/local-repo && createrepo /tmp/local-repo/zmb-store/D2/ )
else
   ( cd /tmp/local-repo && dpkg-scanpackages -m zmb-store/D1/ /dev/null | gzip -9c > zmb-store/D1/Packages.gz )
   ( cd /tmp/local-repo && dpkg-scanpackages -m zmb-store/D2/ /dev/null | gzip -9c > zmb-store/D2/Packages.gz )
fi
