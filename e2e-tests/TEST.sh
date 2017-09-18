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
set -x

CNT=1

ECHO_TEST()
{
   NAME=$1; shift;

   echo "####################################################################################" >&9
   echo "RUNNING TEST $CNT: $NAME ... " >&9

   ((++CNT))
}

S=0
T=0
F=0

assert()
{
   local STR="$1"; shift;

   if [ $# -eq 0 ]
   then
      echo " - ERROR: $STR (INVALID ARGS)" >&9
      echo "####################################################################################" >&9
      exit 1
   fi

   if diff -w <("$@" | sort) <(cat - | sort)
   then
      echo " - PASS: $STR" >&9
      ((++S))
   else
      echo " - FAIL: $STR" >&9
      ((++F))
   fi

   ((++T))
}

assert_870()
{
   local STR="$1"; shift;
   local VER="${FUNCNAME[0]/?*_/}";

   assert "$STR:CHK1:$VER" /opt/rr/bin/abc.sh <<EOM
abc-bin-ver: abc-bin-1
abc-lib-ver: abc-lib-1
cmn-lib-ver: cmn-lib-1
EOM

   assert "$STR:CHK2:$VER" /opt/rr/bin/abc-svc.sh <<EOM
abc-svc-ver: abc-svc-1
EOM
}

assert_871()
{
   local STR="$1"; shift;
   local VER="${FUNCNAME[0]/?*_/}";

   assert "$STR:CHK1:$VER" /opt/rr/bin/abc.sh <<EOM
abc-bin-ver: abc-bin-2
abc-lib-ver: abc-lib-1
cmn-lib-ver: cmn-lib-1
EOM

   assert "$STR:CHK2:$VER" /opt/rr/bin/abc-svc.sh <<EOM
abc-svc-ver: abc-svc-2
EOM
}

assert_872()
{
   local STR="$1"; shift;
   local VER="${FUNCNAME[0]/?*_/}";

   assert "$STR:CHK1:$VER" /opt/rr/bin/abc.sh <<EOM
abc-bin-ver: abc-bin-2
abc-lib-ver: abc-lib-2
cmn-lib-ver: cmn-lib-2
EOM

   assert "$STR:CHK2:$VER" /opt/rr/bin/abc-svc.sh <<EOM
abc-svc-ver: abc-svc-3
EOM
}

assert_873()
{
   local STR="$1"; shift;
   local VER="${FUNCNAME[0]/?*_/}";

   assert "$STR:CHK1:$VER" /opt/rr/bin/abc.sh <<EOM
abc-bin-ver: abc-bin-3
abc-lib-ver: abc-lib-3
cmn-lib-ver: cmn-lib-3
EOM

   assert "$STR:CHK2:$VER" /opt/rr/bin/abc-svc.sh <<EOM
abc-svc-ver: abc-svc-4
EOM
}

assert_874()
{
   local STR="$1"; shift;
   local VER="${FUNCNAME[0]/?*_/}";

   assert "$STR:CHK1:$VER" /opt/rr/bin/abc.sh <<EOM
abc-bin-ver: abc-bin-3
abc-lib-ver: abc-lib-4
cmn-lib-ver: cmn-lib-3
EOM

   assert "$STR:CHK2:$VER" /opt/rr/bin/abc-svc.sh <<EOM
abc-svc-ver: abc-svc-5
EOM
}

assert_900()
{
   local STR="$1"; shift;
   local VER="${FUNCNAME[0]/?*_/}";

   assert "$STR:CHK1:$VER" /opt/rr/bin/abc.sh <<EOM
my-abc-bin-ver: my-abc-bin-1
my-abc-lib-ver: my-abc-lib-1
EOM

   assert "$STR:CHK2:$VER" /opt/rr/bin/abc-svc.sh <<EOM
my-abc-svc-ver: my-abc-svc-1
EOM
}

assert_901()
{
   local STR="$1"; shift;
   local VER="${FUNCNAME[0]/?*_/}";

   assert "$STR:CHK1:$VER" /opt/rr/bin/abc.sh <<EOM
my-abc-bin-ver: my-abc-bin-2
my-abc-lib-ver: my-abc-lib-1
EOM

   assert "$STR:CHK2:$VER" /opt/rr/bin/abc-svc.sh <<EOM
my-abc-svc-ver: my-abc-svc-2
EOM
}

assert_EMPTY()
{
   local STR="$1"; shift;
   local VER="${FUNCNAME[0]/?*_/}";

   assert "$STR:CHK:$VER" pkg_isEmpty <<EOM
EMPTY
EOM
}

pkg_add_repo()
{
   local R_arg=( "$@" );

   if [ -f /etc/redhat-release ]
   then
      > /etc/yum.repos.d/local.repo
   else
      > /etc/apt/sources.list.d/local.list
   fi

   local R;
   for R in "${R_arg[@]}"
   do
      if [ -f /etc/redhat-release ]
      then
         cat >> /etc/yum.repos.d/local.repo <<EOM
[local-$R]
name=Local Repository Demo
baseurl=file:///tmp/local-repo/zmb-store/$R/
enabled=0
gpgcheck=0
protect=1
EOM
      else
         cat >> /etc/apt/sources.list.d/local.list <<EOM
deb [trusted=yes] file:///tmp/local-repo zmb-store/$R/
EOM
      fi
   done
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
      yum -y install --disablerepo=* --enablerepo=local* "$pkg"
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
      DEPS=$(yum -y install --disablerepo=* --enablerepo=local* "$pkg-$ver-*" 2>&1 | grep 'Requires:' | sed -e 's/.*Requires: //' -e 's/ //g' -e 's/[<>][=]/-/' -e 's/[=]/-/')
      if [ "$DEPS" ]
      then
         yum -y install --disablerepo=* --enablerepo=local* "$pkg-$ver" $DEPS
      fi
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
      DEPS=$(yum -y downgrade --disablerepo=* --enablerepo=local* "$pkg-$ver-*" 2>&1 | grep 'Requires:' | sed -e 's/.*Requires: //' -e 's/ //g' -e 's/[<>][=]/-/' -e 's/[=]/-/')
      if [ "$DEPS" ]
      then
         yum -y downgrade --disablerepo=* --enablerepo=local* "$pkg-$ver-*" $DEPS
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
ECHO_TEST "REPO.D1=EMPTY ENABLED=[D1] INIT=EMPTY"

(set +e; pkg_clean; exit 0)

./init.sh
./publish-repo.sh
pkg_add_repo D1
pkg_repo_metaupdate

assert_EMPTY "INIT"

############################################################
ECHO_TEST "REPO.D1=870 ENABLED=[D1] INSTALL=870"

./rel870.sh
./publish-repo.sh
pkg_repo_metaupdate

assert_EMPTY "BEFORE"

pkg_install_latest zmb1-abc-svc

assert_870 AFTER

############################################################
ECHO_TEST "REPO.D1=870,871 ENABLED=[D1] UPGRADE=870->871"

./rel871.sh
./publish-repo.sh
pkg_repo_metaupdate

assert_870 BEFORE

pkg_install_latest zmb1-abc-svc

assert_871 AFTER

############################################################
ECHO_TEST "REPO.D1=870,871 ENABLED=[D1] INSTALL=871"

pkg_clean

assert_EMPTY "BEFORE"

pkg_install_latest zmb1-abc-svc

assert_871 AFTER

############################################################
ECHO_TEST "REPO.D1=870,871 ENABLED=[D1] DOWNGRADE=871->870"

assert_871 BEFORE

pkg_downgrade zmb1-abc-svc '8.7.0'

assert_870 AFTER

############################################################
ECHO_TEST "REPO.D1=870,871 ENABLED=[D1] INSTALL_OLD=870"

pkg_clean

assert_EMPTY "BEFORE"

pkg_install_specified zmb1-abc-svc '8.7.0'

assert_870 AFTER

############################################################
ECHO_TEST "REPO.D1=870,871,872 ENABLED=[D1] UPGRADE=870->872"

./rel872.sh
./publish-repo.sh
pkg_repo_metaupdate

assert_870 BEFORE

pkg_install_latest zmb1-abc-svc

assert_872 AFTER

############################################################
ECHO_TEST "REPO.D1=870,871,872 ENABLED=[D1] INSTALL=872"

pkg_clean

assert_EMPTY "BEFORE"

pkg_install_latest zmb1-abc-svc

assert_872 AFTER

############################################################
ECHO_TEST "REPO.D1=870,871,872,873 ENABLED=[D1] UPGRADE=872->873"

./rel873.sh
./publish-repo.sh
pkg_repo_metaupdate

assert_872 BEFORE

pkg_install_latest zmb1-abc-svc

assert_873 AFTER

############################################################
ECHO_TEST "REPO.D1=870,871,872,873 ENABLED=[D1] INSTALL=873"

pkg_clean

assert_EMPTY "BEFORE"

pkg_install_latest zmb1-abc-svc

assert_873 AFTER

############################################################
ECHO_TEST "REPO.D1=870,871,872,873,874 ENABLED=[D1] UPGRADE=873->874"

./rel874.sh
./publish-repo.sh
pkg_repo_metaupdate

assert_873 BEFORE

pkg_install_latest zmb1-abc-svc

assert_874 AFTER

############################################################
ECHO_TEST "REPO.D1=870,871,872,873,874 ENABLED=[D1] INSTALL=874"

pkg_clean

assert_EMPTY "BEFORE"

pkg_install_latest zmb1-abc-svc

assert_874 AFTER

############################################################
ECHO_TEST "REPO.D1=870,871,872,873,874 REPO.D2=900 ENABLED=[D1] UPGRADE=874->874"

./rel900.sh
./publish-repo.sh
pkg_repo_metaupdate

assert_874 BEFORE

pkg_install_latest zmb1-abc-svc

assert_874 AFTER

############################################################
ECHO_TEST "REPO.D1=870,871,872,873,874 REPO.D2=900 ENABLED=[D1,D2] UPGRADE=874->900"

pkg_add_repo D1 D2
pkg_repo_metaupdate

assert_874 BEFORE

pkg_install_latest zmb2-abc-svc

assert_900 AFTER

############################################################
ECHO_TEST "REPO.D1=870,871,872,873,874 REPO.D2=900,901 ENABLED=[D1,D2] UPGRADE=900->901"

./rel901.sh
./publish-repo.sh
pkg_repo_metaupdate

assert_900 BEFORE

pkg_install_latest zmb2-abc-svc

assert_901 AFTER

############################################################
ECHO_TEST "REPO.D1=870,871,872,873,874 REPO.D2=900,901 ENABLED=[D1] ERASE,INSTALL=874"

pkg_add_repo D1
pkg_repo_metaupdate

assert_901 BEFORE

pkg_clean
pkg_install_latest zmb1-abc-svc

assert_874 AFTER

echo "########################################## END #####################################" >&9
echo " - PASS : $S" >&9
echo " - FAIL : $F" >&9
echo " - TOTAL: $T" >&9
echo "########################################## END #####################################" >&9

if [ "$F" == "0" ]
then
   exit 0;
else
   exit 1;
fi
