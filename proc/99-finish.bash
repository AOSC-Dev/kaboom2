echo "
========================================
Creating /etc/os-release
========================================
"

if ab_match_archgroup mainline; then
	DISTRO="AOSC OS"
	DISTRO_COLOR="1;36"
elif ab_match_archgroup retro; then
	DISTRO="Afterglow"
	DISTRO_COLOR="1;91"
fi

cat > "$KABOOM_STAGE1_SYSROOT"/etc/os-release << EOF
PRETTY_NAME="${DISTRO} (13.0.0)"
NAME="${DISTRO}"
VERSION_ID="13.0.0"
VERSION="13.0.0 (Meow)"
BUILD_ID="$(date "+%Y%m%d")"
ID=aosc
ANSI_COLOR="${DISTRO_COLOR}"
HOME_URL="https://aosc.io/"
SUPPORT_URL="https://github.com/AOSC-Dev/aosc-os-abbs"
BUG_REPORT_URL="https://github.com/AOSC-Dev/aosc-os-abbs/issues"
EOF

cat "$KABOOM_STAGE1_SYSROOT"/etc/os-release

echo "
========================================
Archiving stage 1 sysroot
========================================
"

set_title "Archiving stage1 sysroot"
fakeroot \
	tar --no-same-owner -cJf \
	kaboom-stage1-"$KABOOM_TARGET_ARCH"-"$(date "+%Y%m%d")".tar.xz \
	-C "$KABOOM_STAGE1_SYSROOT" \
	.

echo "
========================================
Stage 1 finished!
========================================
"
abinfo "Output file: kaboom-stage1-$KABOOM_TARGET_ARCH-$(date "+%Y%m%d").tar.xz"
abinfo "Target: $KABOOM_TARGET_ARCH ($KABOOM_TARGET_TRIPLE)"
set_title "Finished!"
