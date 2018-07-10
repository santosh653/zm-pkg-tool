#!/bin/bash

set -e

deploy()
{
   rm -rf build

   PKG_SVC_VER=9.0.0; PKG_SVC_REV=1;
   PKG_ABC_BIN_VER=1.0.0+1493729097; PKG_ABC_BIN_REV=1;
   PKG_ABC_LIB_VER=1.0.0+1493729098; PKG_ABC_LIB_REV=1;

   SVC_DEP=()
   SVC_DEP+=( "--pkg-depends=zmb2-abc-bin (= $PKG_ABC_BIN_VER-$PKG_ABC_BIN_REV)" );
   SVC_DEP+=( "--pkg-depends=zmb2-abc-lib (= $PKG_ABC_LIB_VER-$PKG_ABC_LIB_REV)" );

   # zmb2-abc-lib
   mkdir -p build/stage/zmb2-abc-lib/opt/rr/lib

   cat > build/stage/zmb2-abc-lib/opt/rr/lib/my-abc-lib.sh <<EOM
MY_ABC_LIB_VER="my-abc-lib-1"
EOM

   ../../zm-pkg-tool/pkg-build.pl --out-type=binary --pkg-installs='/opt/rr/' --pkg-name=zmb2-abc-lib --pkg-summary='its zmb-abc-lib' \
      --pkg-version=$PKG_ABC_LIB_VER --pkg-release=$PKG_ABC_LIB_REV

   mv build/dist/*/* /tmp/local-repo/zmb-store/D2/

   # zmb2-abc-bin
   mkdir -p build/stage/zmb2-abc-bin/opt/rr/bin

   cat > build/stage/zmb2-abc-bin/opt/rr/bin/abc.sh <<EOM
set -e
source /opt/rr/lib/my-abc-lib.sh
echo "my-abc-bin-ver: my-abc-bin-1"
echo "my-abc-lib-ver: \$MY_ABC_LIB_VER"
EOM

   chmod +x build/stage/zmb2-abc-bin/opt/rr/bin/abc.sh

   ../../zm-pkg-tool/pkg-build.pl --out-type=binary --pkg-installs='/opt/rr/' --pkg-name=zmb2-abc-bin --pkg-summary='its zmb-abc-bin' \
      --pkg-version=$PKG_ABC_BIN_VER --pkg-release=$PKG_ABC_BIN_REV \
      --pkg-depends='zmb2-abc-lib'

   mv build/dist/*/* /tmp/local-repo/zmb-store/D2/

   # zmb2-abc-svc
   mkdir -p build/stage/zmb2-abc-svc/opt/rr/bin

   cat > build/stage/zmb2-abc-svc/opt/rr/bin/abc-svc.sh <<EOM
echo "my-abc-svc-ver: my-abc-svc-1"
EOM

   chmod +x build/stage/zmb2-abc-svc/opt/rr/bin/abc-svc.sh

   ../../zm-pkg-tool/pkg-build.pl --out-type=binary --pkg-installs='/opt/rr/' --pkg-name=zmb2-abc-svc --pkg-summary='its zmb-abc-svc' \
      --pkg-version=$PKG_SVC_VER --pkg-release=$PKG_SVC_REV \
      "${SVC_DEP[@]}" \
      --pkg-conflicts='zmb1-abc-svc' \
      --pkg-conflicts='zmb1-abc-bin' \
      --pkg-conflicts='zmb1-abc-lib' \
      --pkg-conflicts='zmb1-cmn-lib'

   mv build/dist/*/* /tmp/local-repo/zmb-store/D2/

   echo deployed
}

deploy "$@"
