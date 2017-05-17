#!/bin/bash

set -e

deploy()
{
   SVC_VER=9.0.0; SVC_PKG=1;
   LIB_VER=1.0.1493729098; LIB_PKG=1;
   BIN_VER=1.0.1493729097; BIN_PKG=1;
   SVC_LIB_DEP="= $LIB_VER-$LIB_PKG";
   SVC_BIN_DEP="= $BIN_VER-$BIN_PKG";

   # zmb2-abc-lib
   mkdir -p build/stage/zmb2-abc-lib/opt/rr/lib

   cat > build/stage/zmb2-abc-lib/opt/rr/lib/my-abc-lib.sh <<EOM
MY_ABC_LIB_VER="my-lib-1"
EOM

   ../../zm-pkg-tool/pkg-build.pl --out-type=binary --pkg-install-list='/opt/rr/' --pkg-name=zmb2-abc-lib --pkg-summary='its zmb-abc-lib' \
      --pkg-version=$LIB_VER --pkg-release=$LIB_PKG \
      --pkg-depends-list='zmb2-abc-svc' \
      --pkg-obsoletes-list='zmb1-abc-lib'

   mv build/dist/*/* /tmp/local-repo/zmb-store/D2/

   # zmb2-abc-bin
   mkdir -p build/stage/zmb2-abc-bin/opt/rr/bin

   cat > build/stage/zmb2-abc-bin/opt/rr/bin/abc.sh <<EOM
set -e
source /opt/rr/lib/my-abc-lib.sh
echo "my-bin-ver: my-bin-1"
echo "my-lib-ver: \$MY_ABC_LIB_VER"
EOM

   chmod +x build/stage/zmb2-abc-bin/opt/rr/bin/abc.sh

   ../../zm-pkg-tool/pkg-build.pl --out-type=binary --pkg-install-list='/opt/rr/' --pkg-name=zmb2-abc-bin --pkg-summary='its zmb-abc-bin' \
      --pkg-version=$BIN_VER --pkg-release=$BIN_PKG \
      --pkg-depends-list='zmb2-abc-lib' \
      --pkg-depends-list='zmb2-abc-svc' \
      --pkg-obsoletes-list='zmb1-abc-bin'

   mv build/dist/*/* /tmp/local-repo/zmb-store/D2/

   # zmb2-abc-svc
   mkdir -p build/stage/zmb2-abc-svc/

   ../../zm-pkg-tool/pkg-build.pl --out-type=binary --pkg-name=zmb2-abc-svc --pkg-summary='its zmb-abc-svc' \
      --pkg-version=$SVC_VER --pkg-release=$SVC_PKG \
      --pkg-depends-list="zmb2-abc-bin ($SVC_BIN_DEP)" \
      --pkg-depends-list="zmb2-abc-lib ($SVC_LIB_DEP)" \
      --pkg-obsoletes-list='zmb1-abc-svc'

   mv build/dist/*/* /tmp/local-repo/zmb-store/D2/

   echo deployed
}

deploy "$@"
