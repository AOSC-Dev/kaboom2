export KABOOM_CUR_STAGE=stage1
export KABOOM_CUR_SYSROOT="$KABOOM_STAGE1_SYSROOT"

if [ ! -e "$KABOOM_STAGE1_SYSROOT" ] ; then
	abinfo "Copying stage 0 sysroot as stage 1 ..."
	cp -a "$KABOOM_STAGE0_SYSROOT" "$KABOOM_STAGE1_SYSROOT"
fi

abinfo "Linking toolchain sysroot to stage 1 sysroot ..."
ln -snfv ../stage1-"$KABOOM_TARGET_ARCH" "$KABOOM_TOOLCHAIN_SYSROOT"

echo "
========================================
Building stage1 sysroot
========================================
"

export CFLAGS="$KABOOM_TARGET_CFLAGS -O2"
export CXXFLAGS="$KABOOM_TARGET_CXXFLAGS -O2"

execute_sequence || {
	abdie "Sequence ‘$KABOOM_CUR_STAGE’ failed."
}
