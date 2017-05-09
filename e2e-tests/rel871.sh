#!/bin/bash

deploy()
{
   SVC_VER=8.7.1; SVC_PKG=1;
   LIB_VER=1.0.1493728878; LIB_PKG=1;
   BIN_VER=2.0.1493729407; BIN_PKG=1;

   # zmb1-abc-lib

   # zmb1-abc-bin
   mkdir -p build/stage/zmb1-abc-bin/opt/rr/bin

   cat > build/stage/zmb1-abc-bin/opt/rr/bin/abc.sh <<EOM
   set -e
   source /opt/rr/lib/abc-lib.sh
   echo "bin-ver: bin-2"
   echo "lib-ver: \$ABC_LIB_VER"
EOM

   chmod +x build/stage/zmb1-abc-bin/opt/rr/bin/abc.sh

   ../../zm-pkg-tool/pkg-build.pl --out-type=binary --pkg-install-list='/opt/rr/' --pkg-name=zmb1-abc-bin --pkg-summary='its zmb-abc-bin' \
      --pkg-version=$BIN_VER --pkg-release=$BIN_PKG \
      --pkg-depends-list='zmb1-abc-lib' \
      --pkg-depends-list='zmb1-abc-svc' \
      --pkg-obsoletes-list='zmb0-abc-bin'

   mv build/dist/*/* /tmp/local-repo/zmb-store/D1/

   # zmb1-abc-svc
   mkdir -p build/stage/zmb1-abc-svc/

   ../../zm-pkg-tool/pkg-build.pl --out-type=binary --pkg-name=zmb1-abc-svc --pkg-summary='its zmb' \
      --pkg-version=$SVC_VER --pkg-release=$SVC_PKG \
      --pkg-depends-list="zmb1-abc-bin (= $BIN_VER-$BIN_PKG)" \
      --pkg-depends-list="zmb1-abc-lib (= $LIB_VER-$LIB_PKG)" \
      --pkg-obsoletes-list='zmb0-abc-svc'

   mv build/dist/*/* /tmp/local-repo/zmb-store/D1/

   echo deployed
}

deploy "$@"
