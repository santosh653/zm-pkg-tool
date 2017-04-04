Prerequisites:
   sudo apt install dpkg-dev debhelper


Example:
   path../zm-pkg-tool/pkg-build.pl \
      --output-base-dir=build \
      --pkg-version=1.0.2 \
      --pkg-release=1zimbra8.7b1
      --pkg-path=./pkg-spec/zimbra-drive \
      --pkg-summary="Zimbra Drive Extensions" \
      --pkg-depends-list='zimbra-core' \
      --pkg-install-list='/opt/zimbra/lib/ext/zimbradrive' \
      --pkg-install-list='/opt/zimbra/lib/ext/zimbradrive/*' \
      --pkg-install-list='/opt/zimbra/zimlets/*'

