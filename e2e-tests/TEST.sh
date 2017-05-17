#!/bin/bash

set -e

if [ $(whoami) != "root" ]
then
   echo "REQUIRES ROOT PERMISSIONS"
   exit 1
fi

echo "See /tmp/pkg-test.log for details"

exec 9>&1
exec 1>/tmp/pkg-test.log 2>&1

CNT=1

ECHO_TEST()
{
   NAME=$1; shift;

   echo "####################################################################################" >&9
   echo "RUNNING TEST $CNT: $NAME ... " >&9

   ((++CNT))
}

assert()
{
   local STR="$1"; shift;

   if [ $# -eq 0 ]
   then
      echo " - ERROR: $STR (INVALID ARGS)" >&9
      echo "####################################################################################" >&9
      exit 1
   fi

   diff -w <("$@" | sort) <(cat - | sort)
   if [ $? -ne 0 ]
   then
      echo " - FAIL: $STR" >&9
      echo "####################################################################################" >&9
      exit 1
   else
      echo " - PASS: $STR" >&9
   fi

   (( ++COUNT ))
}

pkg_add_repo()
{
   if [ -f /etc/redhat-release ]
   then
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
   else
      cat > /etc/apt/sources.list.d/local.list <<EOM
deb file:///tmp/local-repo zmb-store/D1/
deb file:///tmp/local-repo zmb-store/D2/
EOM
   fi
}

pkg_isEmpty()
{
   if [ -x /opt/rr/bin/abc.sh ]
   then
      echo "FOUND"
   else
      echo "EMPTY"
   fi
}

pkg_clean()
{
   if [ -f /etc/redhat-release ]
   then
      yum -y erase 'zmb1*' 'zmb2*'
   else
      apt-get remove -y 'zmb1*' 'zmb2*'
   fi
}

pkg_repo_metaupdate()
{
   if [ -f /etc/redhat-release ]
   then
      yum --disablerepo=* --enablerepo=local* clean all
   else
      apt-get update
   fi
}

pkg_install_latest()
{
   local pkg="$1"; shift;

   if [ -f /etc/redhat-release ]
   then
      yum -y install --disablerepo=* --enablerepo=local-D1 "$pkg"
   else
      apt-get install -y --allow-unauthenticated "$pkg"
   fi
}

pkg_install_specified()
{
   local pkg="$1"; shift;
   local ver="$1"; shift;

   if [ -f /etc/redhat-release ]
   then
      yum -y install --disablerepo=* --enablerepo=local-D1 "$pkg-$ver"
   else
      DEPS=$(apt-get install -y --allow-unauthenticated "$pkg=$ver-*" | grep -o -e 'Depends:.*)' | sed -e 's/Depends: //' -e 's/[( )]//g')
      if [ "$DEPS" ]
      then
         apt-get install -y --allow-unauthenticated "$pkg=$ver-*" $DEPS
      fi
   fi
}

pkg_downgrade()
{
   local pkg="$1"; shift;
   local ver="$1"; shift;

   if [ -f /etc/redhat-release ]
   then
      DEPS=$(yum -y downgrade --disablerepo=* --enablerepo=local-D1 "$pkg-$ver-*" 2>&1 | grep 'Requires:' | sed -e 's/.*Requires: //' -e 's/ //g' -e 's/[<>][=]/-/' -e 's/[=]/-/')
      if [ "$DEPS" ]
      then
         yum -y downgrade --disablerepo=* --enablerepo=local-D1 "$pkg-$ver-*" $DEPS
      fi
   else
      DEPS=$(apt-get install -y --allow-unauthenticated --allow-downgrades "$pkg=$ver-*" | grep -o -e 'Depends:.*)' | sed -e 's/Depends: //' -e 's/[( )]//g')
      if [ "$DEPS" ]
      then
         apt-get install -y --allow-unauthenticated --allow-downgrades "$pkg=$ver-*" $DEPS
      fi
   fi
}

############################################################
ECHO_TEST "REPO=EMPTY INIT=EMPTY"

(set +e; pkg_clean; exit 0)

./init.sh
./publish-repo.sh
pkg_add_repo
pkg_repo_metaupdate

assert "AFTER:EMPTY" pkg_isEmpty <<EOM
EMPTY
EOM

############################################################
ECHO_TEST "REPO=870 INSTALL=870"

./rel870.sh
./publish-repo.sh
pkg_repo_metaupdate

assert "BEFORE:EMPTY" pkg_isEmpty <<EOM
EMPTY
EOM

pkg_install_latest zmb1-abc-svc

assert "AFTER:870" /opt/rr/bin/abc.sh <<EOM
bin-ver: bin-1
lib-ver: lib-1
EOM

############################################################
ECHO_TEST "REPO=870,871 UPGRADE=870->871"

./rel871.sh
./publish-repo.sh
pkg_repo_metaupdate

assert "BEFORE:870" /opt/rr/bin/abc.sh <<EOM
bin-ver: bin-1
lib-ver: lib-1
EOM

pkg_install_latest zmb1-abc-svc

assert "AFTER:871" /opt/rr/bin/abc.sh <<EOM
bin-ver: bin-2
lib-ver: lib-1
EOM

############################################################
ECHO_TEST "REPO=870,871 INSTALL=871"

pkg_clean

assert "BEFORE:EMPTY" pkg_isEmpty <<EOM
EMPTY
EOM

pkg_install_latest zmb1-abc-svc

assert "AFTER:871" /opt/rr/bin/abc.sh <<EOM
bin-ver: bin-2
lib-ver: lib-1
EOM

############################################################
ECHO_TEST "REPO=870,871 DOWNGRADE=871->870"

assert "BEFORE:871" /opt/rr/bin/abc.sh <<EOM
bin-ver: bin-2
lib-ver: lib-1
EOM

pkg_downgrade zmb1-abc-svc '8.7.0'

assert "AFTER:870" /opt/rr/bin/abc.sh <<EOM
bin-ver: bin-1
lib-ver: lib-1
EOM

############################################################
ECHO_TEST "REPO=870,871 INSTALL=870"

pkg_clean

assert "BEFORE:EMPTY" pkg_isEmpty <<EOM
EMPTY
EOM

pkg_install_specified zmb1-abc-svc '8.7.0'

assert "AFTER:870" /opt/rr/bin/abc.sh <<EOM
bin-ver: bin-1
lib-ver: lib-1
EOM

############################################################
ECHO_TEST "REPO=870,871,872 UPGRADE=870->872"

./rel872.sh
./publish-repo.sh
pkg_repo_metaupdate

assert "BEFORE:870" /opt/rr/bin/abc.sh <<EOM
bin-ver: bin-1
lib-ver: lib-1
EOM

pkg_install_latest zmb1-abc-svc

assert "AFTER:872" /opt/rr/bin/abc.sh <<EOM
bin-ver: bin-2
lib-ver: lib-3
EOM

############################################################

echo "########################################## END #####################################" >&9
