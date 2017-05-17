#!/bin/bash

set -e

deploy()
{
   SVC_VER="8.7.2"; SVC_PKG="1";
   LIB_VER="1.0.0+1493739799"; LIB_PKG="1";
   BIN_VER="1.0.0+1493729407"; BIN_PKG="1";

   SVC_LIB_DEP=( "--pkg-depends-list=zmb1-abc-lib (= $LIB_VER-$LIB_PKG)" );
   SVC_BIN_DEP=( "--pkg-depends-list=zmb1-abc-bin (= $BIN_VER-$BIN_PKG)" );

   # zmb1-abc-lib
   mkdir -p build/stage/zmb1-abc-lib/opt/rr/lib

   cat > build/stage/zmb1-abc-lib/opt/rr/lib/abc-lib.sh <<EOM
ABC_LIB_VER="lib-3"
EOM

   ../../zm-pkg-tool/pkg-build.pl --out-type=binary --pkg-install-list='/opt/rr/' --pkg-name=zmb1-abc-lib --pkg-summary='its zmb-abc-lib' \
      --pkg-version=$LIB_VER --pkg-release=$LIB_PKG \
      --pkg-depends-list='zmb1-abc-svc' \
      --pkg-obsoletes-list='zmb0-abc-lib'

   mv build/dist/*/* /tmp/local-repo/zmb-store/D1/

   # zmb1-abc-bin

   # zmb1-abc-svc
   mkdir -p build/stage/zmb1-abc-svc/

   ../../zm-pkg-tool/pkg-build.pl --out-type=binary --pkg-name=zmb1-abc-svc --pkg-summary='its zmb-abc-svc' \
      --pkg-version=$SVC_VER --pkg-release=$SVC_PKG \
      "${SVC_BIN_DEP[@]}" \
      "${SVC_LIB_DEP[@]}" \
      --pkg-obsoletes-list='zmb0-abc-svc'

   mv build/dist/*/* /tmp/local-repo/zmb-store/D1/

   echo deployed
}

deploy "$@"
