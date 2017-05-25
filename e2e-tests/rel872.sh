#!/bin/bash

set -e

deploy()
{
   PKG_SVC_VER="8.7.2"; PKG_SVC_REV="1";
   PKG_ABC_LIB_VER="1.0.0+1493739799"; PKG_ABC_LIB_REV="1";
   PKG_ABC_BIN_VER="1.0.0+1493729407"; PKG_ABC_BIN_REV="1";

   SVC_DEP=()
   SVC_DEP+=( "--pkg-depends-list=zmb1-abc-lib (= $PKG_ABC_LIB_VER-$PKG_ABC_LIB_REV)" );
   SVC_DEP+=( "--pkg-depends-list=zmb1-abc-bin (= $PKG_ABC_BIN_VER-$PKG_ABC_BIN_REV)" );

   # zmb1-abc-lib
   mkdir -p build/stage/zmb1-abc-lib/opt/rr/lib

   cat > build/stage/zmb1-abc-lib/opt/rr/lib/abc-lib.sh <<EOM
ABC_LIB_VER="abc-lib-3"
EOM

   ../../zm-pkg-tool/pkg-build.pl --out-type=binary --pkg-install-list='/opt/rr/' --pkg-name=zmb1-abc-lib --pkg-summary='its zmb-abc-lib' \
      --pkg-version=$PKG_ABC_LIB_VER --pkg-release=$PKG_ABC_LIB_REV \
      --pkg-depends-list='zmb1-abc-svc' \
      --pkg-obsoletes-list='zmb0-abc-lib'

   mv build/dist/*/* /tmp/local-repo/zmb-store/D1/

   # zmb1-abc-bin

   # zmb1-abc-svc
   mkdir -p build/stage/zmb1-abc-svc/

   ../../zm-pkg-tool/pkg-build.pl --out-type=binary --pkg-name=zmb1-abc-svc --pkg-summary='its zmb-abc-svc' \
      --pkg-version=$PKG_SVC_VER --pkg-release=$PKG_SVC_REV \
      "${SVC_DEP[@]}" \
      --pkg-obsoletes-list='zmb0-abc-svc'

   mv build/dist/*/* /tmp/local-repo/zmb-store/D1/

   echo deployed
}

deploy "$@"
