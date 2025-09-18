export KABOOM_CUR_STAGE=stage0
export KABOOM_CUR_SYSROOT="$KABOOM_STAGE0_SYSROOT"

abinfo "Linking toolchain sysroot to stage 0 sysroot ..."
ln -snfv ../stage0-"$KABOOM_TARGET_ARCH" "$KABOOM_TOOLCHAIN_SYSROOT"

echo "
========================================
Building stage0 sysroot
========================================
"

export CFLAGS="$KABOOM_TARGET_CFLAGS -O2"
export CXXFLAGS="$KABOOM_TARGET_CXXFLAGS -O2"

execute_sequence || {
	abdie "Sequence ‘$KABOOM_CUR_STAGE’ failed."
}
