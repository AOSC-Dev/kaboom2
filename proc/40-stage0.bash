export KABOOM_CUR_STAGE=stage0
export KABOOM_CUR_SYSROOT="$KABOOM_STAGE0_SYSROOT"

if [ -n "$KABOOM_CONTINUE_STAGE" ] && \
	[ "$KABOOM_CONTINUE_STAGE" != "$KABOOM_CUR_STAGE" ] ; then
	abinfo "$KABOOM_CUR_STAGE: Continuing to stage ‘$KABOOM_CONTINUE_STAGE’."
	return 0
fi

abinfo "Linking toolchain sysroot to stage 0 sysroot ..."
ln -snfv ../stage0-"$KABOOM_TARGET_ARCH" "$KABOOM_TOOLCHAIN_SYSROOT"

echo "
========================================
Building stage0 sysroot
========================================
"

export CFLAGS="$KABOOM_TARGET_CFLAGS -O2"
export CXXFLAGS="$KABOOM_TARGET_CXXFLAGS -O2"
export CPPFLAGS="$KABOOM_TARGET_CPPFLAGS -O2"
export ASFLAGS="$KABOOM_TARGET_ASFLAGS"

execute_sequence || {
	abdie "Sequence ‘$KABOOM_CUR_STAGE’ failed."
}

# Clear the continuation flag
if [ -n "$KABOOM_CONTINUE_STAGE" ] && [ "$KABOOM_CONTINUE_STAGE" == "$KABOOM_CUR_STAGE" ] ; then
	unset KABOOM_CONTINUE_STAGE KABOOM_CONTINUE_PACKAGE
fi
