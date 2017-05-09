#!/bin/bash

set -e

if [ -f /etc/redhat-release ]
then
   cat <<EOX
cat > /etc/yum.repos.d/local.repo <<EOM
[local-D1]
name=Local Repository Demo
baseurl=file:///tmp/local-repo/zmb-store/D1/
enabled=0
gpgcheck=0
protect=1

[local-D2]
name=Local Repository Demo
baseurl=file:///tmp/local-repo/zmb-store/D2/
enabled=0
gpgcheck=0
protect=1
EOM
EOX
else
   cat <<EOX
cat > /etc/apt/sources.list.d/local.list <<EOM
deb file:///tmp/local-repo zmb-store/D1/
deb file:///tmp/local-repo zmb-store/D2/
EOM
EOX
fi

echo
echo
echo
echo -n "Configure repo using above script. press a key to continue."; read

rm -rf build/
rm -rf /tmp/local-repo
mkdir -p /tmp/local-repo/zmb-store/D1/
mkdir -p /tmp/local-repo/zmb-store/D2/

echo
echo -n deploy rel8.7.0?; read
./rel870.sh
./publish-repo.sh

echo
echo -n deploy rel9.0.0?; read
. rel900.sh
./publish-repo.sh

echo
echo -n deploy rel8.7.1?; read
. rel871.sh
./publish-repo.sh

echo
echo -n deploy rel9.0.1?; read
. rel901.sh
./publish-repo.sh

echo
echo -n deploy rel8.7.2?; read
. rel872.sh
./publish-repo.sh
