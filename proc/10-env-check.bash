#!/bin/bash
# Adapted from Linux from Scratch
# Simple script to list version numbers of critical development tools

echo -e "
========================================
Performing environment check ...
========================================
"

# Reset LC_ALL to POSIX to ensure output consistency.
export LC_ALL=C.UTF-8

abinfo "Testing for basic programs ..."
for prog in \
	awk bash bison cat diff find g++ gcc gawk grep gzip ld m4 make \
	makeinfo patch perl python3 sed tar tic yacc xz; do
	abinfo "Testing if $prog exists ..."
	command -v $prog > /dev/null || \
		aberr "$prog not found."
done

_BASH=$(readlink -f /bin/sh)
abinfo "Testing if /bin/sh points to bash ..."
echo $_BASH | grep -q bash || \
	aberr "/bin/sh does not point to bash."
unset MYSH

abinfo "Testing if awk is gawk ..."
_GAWK=$(readlink -f /bin/awk)
echo $_GAWK | grep -q gawk || \
	aberr "/bin/awk does not point to gawk."

pushd "$KABOOM_BUILD_DIR"
abinfo "Testing if gcc produces a binary ..."
echo $'#include <stdio.h>\nint main(){printf ("Test\\n");return 0;}' > dummy.c && \
	gcc -o dummy dummy.c
if [ ! -x dummy ]; then
	aberr "gcc failed to produce a binary ..."
fi
abinfo "Testing if gcc produces a binary ..."
echo $'#include <iostream>\nint main(){std::cout << "Test" << std::endl;return 0;}' > dummy.cpp && \
	g++ -o dummy dummy.cpp
if [ ! -x dummy ]; then
	aberr "g++ failed to produce a binary ..."
fi
rm -f dummy.c dummy.cpp dummy
popd

if [ "$KABOOM_ERROR" = "1" ] ; then
	abdie "Environment check failed. See the output above for details."
fi

abinfo "Checking for target definitions ..."
undefined=()
for var in \
	KABOOM_TARGET_ARCH \
	KABOOM_TARGET_TRIPLE \
	KABOOM_TARGET_KERNEL_ARCH \
	KABOOM_TARGET_CFLAGS \
	KABOOM_TARGET_CXXFLAGS \
	KABOOM_OPENSSL_TARGET
do
	if [ -z "${!var}" ] ; then
		undefined+=($var)
	fi
done
if [ "${#undefined[@]}" -gt 0 ] ; then
	aberr "The following required variables are not defined:"
	for undef in "${undefined[@]}" ; do
		aberr "- ‘$undef’"
	done
	abdie "Please check your target/"$KABOOM_TARGET_ARCH" file."
fi


#if [ "$_ARCH" != "$KABOOM_TARGET_ARCH" ] ; then
#	# We are cross compiling the stage 0.
#	CROSS_STAGE0=1
#	abinfo "Cross compiling from $_HOST_TRIPLE to $_TARGET"
if systemd-detect-virt -qc ; then
	abwarn "Make sure the host system has $_BINFMT registered in binfmt_misc registry."
elif [ -n "${KABOOM_BINFMT_SKIP}" ] && [ "${KABOOM_BINFMT_SKIP/$KABOOM_HOST_ARCH/}" != "${KABOOM_BINFMT_SKIP}" ] ; then
	if [ "$KABOOM_TARGET_ARCH" = "arm64" ] ; then
		abwarn "Be aware that not all AArch64 processors are capable of running AArch32 binaries natively."
		abwarn "Please check if your machine supports 32-bit EL0 and EL1 before continuing."
	else
		abinfo "Target binaries can run natively. No binfmt support is required."
	fi
elif [ "$KABOOM_NATIVE_STAGE1" = "1" ] && [ -z "$KABOOM_BINFMT" ]; then
	aberr "QEMU user emulation is not available for current architecture.\n" \
	"Try running kaboom with '-s stage0' to produce a minimal stage 0 environment."
	abdie "Otherwise, disable native stage1 builds to proceed."
 	elif [ ! -e /proc/sys/fs/binfmt_misc/"$KABOOM_BINFMT" ] ; then
	aberr "Binfmt entry $KABOOM_BINFMT does not exist in /proc/sys/fs/binfmt_misc."
	abdie "Make sure the corresponding qemu-user-static package is installed."
fi

echo	"========================================"
echo	"            Job Description"
echo	"========================================"
echo	"Host			: $KABOOM_HOST_TRIPLE"
echo	"Target			: $KABOOM_TARGET_TRIPLE"
echo	"Toolchain directory	: $KABOOM_TOOLCHAIN_PREFIX"
echo	"Build diretory		: $KABOOM_BUILD_DIR"
echo	"Stage 0 directory	: $KABOOM_STAGE0_SYSROOT"
echo	"Stage 1 directory	: $KABOOM_STAGE1_SYSROOT"
echo	"Cross entire stage 1	: yes"
