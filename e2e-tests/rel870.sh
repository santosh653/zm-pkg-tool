#!/bin/bash

set -e

deploy()
{
   rm -rf build

   PKG_SVC_VER="8.7.0"; PKG_SVC_REV="1";
   PKG_ABC_BIN_VER="1.0.0+1493728877"; PKG_ABC_BIN_REV="1";
   PKG_ABC_LIB_VER="1.0.0+1493728878"; PKG_ABC_LIB_REV="1";

   SVC_DEP=()
   SVC_DEP+=( "--pkg-depends=zmb1-abc-bin (= $PKG_ABC_BIN_VER-$PKG_ABC_BIN_REV)" );
   SVC_DEP+=( "--pkg-depends=zmb1-abc-lib (= $PKG_ABC_LIB_VER-$PKG_ABC_LIB_REV)" );

   # zmb1-abc-lib
   mkdir -p build/stage/zmb1-abc-lib/opt/rr/lib

   cat > build/stage/zmb1-abc-lib/opt/rr/lib/abc-lib.sh <<EOM
ABC_LIB_VER="abc-lib-1"
EOM

   cat > build/stage/zmb1-abc-lib/opt/rr/lib/cmn-lib.sh <<EOM
CMN_LIB_VER="cmn-lib-1"
EOM

   ../../zm-pkg-tool/pkg-build.pl --out-type=binary --pkg-installs='/opt/rr/' --pkg-name=zmb1-abc-lib --pkg-summary='its zmb-abc-lib' \
      --pkg-version=$PKG_ABC_LIB_VER --pkg-release=$PKG_ABC_LIB_REV

   mv build/dist/*/* /tmp/local-repo/zmb-store/D1/

   # zmb1-abc-bin
   mkdir -p build/stage/zmb1-abc-bin/opt/rr/bin

   cat > build/stage/zmb1-abc-bin/opt/rr/bin/abc.sh <<EOM
set -e
source /opt/rr/lib/abc-lib.sh
source /opt/rr/lib/cmn-lib.sh
echo "abc-bin-ver: abc-bin-1"
echo "abc-lib-ver: \$ABC_LIB_VER"
echo "cmn-lib-ver: \$CMN_LIB_VER"
EOM

   chmod +x build/stage/zmb1-abc-bin/opt/rr/bin/abc.sh

   ../../zm-pkg-tool/pkg-build.pl --out-type=binary --pkg-installs='/opt/rr/' --pkg-name=zmb1-abc-bin --pkg-summary='its zmb-abc-bin' \
      --pkg-version=$PKG_ABC_BIN_VER --pkg-release=$PKG_ABC_BIN_REV \
      --pkg-depends='zmb1-abc-lib'

   mv build/dist/*/* /tmp/local-repo/zmb-store/D1/

   # zmb1-abc-svc
   mkdir -p build/stage/zmb1-abc-svc/opt/rr/bin

   cat > build/stage/zmb1-abc-svc/opt/rr/bin/abc-svc.sh <<EOM
echo "abc-svc-ver: abc-svc-1"
EOM

   chmod +x build/stage/zmb1-abc-svc/opt/rr/bin/abc-svc.sh

   ../../zm-pkg-tool/pkg-build.pl --out-type=binary --pkg-installs='/opt/rr/' --pkg-name=zmb1-abc-svc --pkg-summary='its zmb-abc-svc' \
      --pkg-version=$PKG_SVC_VER --pkg-release=$PKG_SVC_REV \
      "${SVC_DEP[@]}"

   mv build/dist/*/* /tmp/local-repo/zmb-store/D1/

   echo deployed
}

deploy "$@"
