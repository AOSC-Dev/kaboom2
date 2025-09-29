export KABOOM_CUR_STAGE=tools
export KABOOM_CUR_SYSROOT="$KABOOM_STAGE0_SYSROOT"

if [ -n "$KABOOM_CONTINUE_STAGE" ] && \
	[ "$KABOOM_CONTINUE_STAGE" != "$KABOOM_CUR_STAGE" ] ; then
	abinfo "$KABOOM_CUR_STAGE: Continuing to stage ‘$KABOOM_CONTINUE_STAGE’."
	return 0
fi

echo "
========================================
Prepairing stage 0 sysroot directory structure
========================================
"

mkdir -pv "$KABOOM_CUR_SYSROOT"
for d in boot dev etc home media mnt opt proc root run sys tmp var usr ; do
	mkdir -pv "$KABOOM_CUR_SYSROOT"/"$d"
done

for d in bin lib libexec local include share src ; do
	mkdir -pv "$KABOOM_CUR_SYSROOT"/usr/"$d"
done

ln -snfv usr/bin "$KABOOM_CUR_SYSROOT"/bin
ln -snfv usr/lib "$KABOOM_CUR_SYSROOT"/lib
ln -snfv usr/bin "$KABOOM_CUR_SYSROOT"/sbin
ln -snfv bin "$KABOOM_CUR_SYSROOT"/usr/sbin

if bool "$KABOOM_LINK_LIB64" ; then
	ln -snfv usr/lib "$KABOOM_CUR_SYSROOT"/lib64
	ln -snfv lib "$KABOOM_CUR_SYSROOT"/usr/lib64
fi

ln -snfv ../stage0-"$KABOOM_TARGET_ARCH" "$KABOOM_TOOLCHAIN_SYSROOT"

echo "
========================================
Building cross-compile toolchain
========================================
"

export CFLAGS="${KABOOM_HOST_CFLAGS}"
export CXXFLAGS="${KABOOM_HOST_CXXFLAGS}"
export CPPFLAGS="${KABOOM_HOST_CPPFLAGS}"

export CFLAGS_FOR_TARGET="$KABOOM_TARGET_CFLAGS"
export CXXFLAGS_FOR_TARGET="$KABOOM_TARGET_CXXFLAGS"
export CPPFLAGS_FOR_TARGET="$KABOOM_TARGET_CPPFLAGS"

execute_sequence || {
	abdie "Sequence ‘$KABOOM_CUR_STAGE’ failed."
}

unset CFLAGS CXXFLAGS CPPFLAGS \
	CFLAGS_FOR_TARGET CXXFLAGS_FOR_TARGET CPPFLAGS_FOR_TARGET

# Clear the continuation flag
if [ -n "$KABOOM_CONTINUE_STAGE" ] ; then
	unset KABOOM_CONTINUE_STAGE KABOOM_CONTINUE_PACKAGE
fi
