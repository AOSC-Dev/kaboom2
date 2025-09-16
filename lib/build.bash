export PATH="$KABOOM_TOOLCHAIN_DIR"/bin:"$PATH"
export KABOOM_TARGET_CC="$KABOOM_TOOLCHAIN_DIR/bin/$KABOOM_TARGET_TRIPLE-gcc"
export KABOOM_TARGET_CXX="$KABOOM_TOOLCHAIN_DIR/bin/$KABOOM_TARGET_TRIPLE-g++"
export KABOOM_TARGET_LD="$KABOOM_TOOLCHAIN_DIR/bin/$KABOOM_TARGET_TRIPLE-ld"
export KABOOM_TARGET_AS="$KABOOM_TOOLCHAIN_DIR/bin/$KABOOM_TARGET_TRIPLE-as"
export KABOOM_TARGET_STRIP="$KABOOM_TOOLCHAIN_DIR/bin/$KABOOM_TARGET_TRIPLE-strip"
export KABOOM_TARGET_AR="$KABOOM_TOOLCHAIN_DIR/bin/$KABOOM_TARGET_TRIPLE-ar"
export KABOOM_TARGET_RANLIB="$KABOOM_TOOLCHAIN_DIR/bin/$KABOOM_TARGET_TRIPLE-ranlib"
export KABOOM_TARGET_PKGCONFIG="$KABOOM_TOOLCHAIN_DIR/bin/$KABOOM_TARGET_TRIPLE-pkg-config"
# A symlink to the current stage sysroot
export KABOOM_TOOLCHAIN_SYSROOT="$KABOOM_TOOLCHAIN_DIR"/sysroot

# Common definition of host toolchain.
KABOOM_AUTOTOOLS_TOOLS_DEF=(
	"--host=$KABOOM_HOST_TRIPLE"
	"--build=$KABOOM_HOST_TRIPLE"
	"--target=$KABOOM_TARGET_TRIPLE"
	"--prefix=$KABOOM_TOOLCHAIN_DIR"
	"--with-sysroot=$KABOOM_TOOLCHAIN_SYSROOT"
	"--enable-year2038"
	"--enable-largefile"
)

# For host applications in the toolchain prefix.
KABOOM_AUTOTOOLS_TOOLS_DEF2=(
	"--host=$KABOOM_HOST_TRIPLE"
	"--build=$KABOOM_HOST_TRIPLE"
	"--prefix=$KABOOM_TOOLCHAIN_DIR"
	"--with-sysroot=$KABOOM_TOOLCHAIN_SYSROOT"
	"--enable-year2038"
	"--enable-largefile"
)

KABOOM_AUTOTOOLS_NATIVE_DEF=(
	"--host=$KABOOM_TARGET_TRIPLE"
	"--build=$KABOOM_HOST_TRIPLE"
	"--prefix=/usr"
	"--enable-year2038"
	"--enable-largefile"
)
if bool "$KABOOM_CROSS_STAGE1" ; then
	# NOTE: some packages may require this while cross compiling.
	KABOOM_AUTOTOOLS_NATIVE_DEF+=(
		"--with-sysroot=$KABOOM_TOOLCHAIN_SYSROOT"
	)
fi

if bool "$KABOOM_CROSS_STAGE1" ; then
	KABOOM_CMAKE_NATIVE_DEF=(
		"-DCMAKE_C_COMPILER=$KABOOM_TARGET_CC"
		"-DCMAKE_CXX_COMPILER=$KABOOM_TARGET_CXX"
		"-DCMAKE_SYSTEM_NAME=Linux"
		"-DCMAKE_SYSTEM_PROCESSOR=$KABOOM_KERNEL_ARCH"
		"-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER"
		"-DCMAKE_INSTALL_PREFIX=/usr"
		"-DPKG_CONFIG_EXECUTABLE=$KABOOM_TARGET_PKGCONFIG"
	)
else
	KABOOM_CMAKE_NATIVE_DEF=(
		"-DCMAKE_INSTALL_PREFIX=/usr"
	)
fi

# mkdir -p && cd
md() {
	mkdir -p "$1"
	cd "$1"
}

_configure() {
	local c="$PWD"/configure
	if [ ! -x "$c" ] ; then
		c="$(realpath $PWD/..)"/configure
	fi
	if [ ! -x "$c" ] ; then
		abdie "Can not find the configure script."
	fi
	"$c" "$@"
}

configure_tools() {
	_configure "${KABOOM_AUTOTOOLS_TOOLS_DEF[@]}" \
		"${ARCH_DEF[@]}" \
		"$@" || abdie \
		"Autotools configuration failed for ‘$PKGNAME-$PKGVER’ during sequence ‘$KABOOM_CUR_STAGE’."
}

configure_native() {
	_configure "${KABOOM_AUTOTOOLS_NATIVE_DEF[@]}" \
		"${ARCH_DEF[@]}" \
		"$@" || abdie \
		"Autotools configuration failed for ‘$PKGNAME-$PKGVER’ during sequence ‘$KABOOM_CUR_STAGE’."
}

# For applications within the toolchain prefix.
configure_native2() {
	_configure "${KABOOM_AUTOTOOLS_NATIVE_DEF[@]}" \
		"${ARCH_DEF[@]}" \
		"$@" || abdie \
		"Autotools configuration failed for ‘$PKGNAME-$PKGVER’ during sequence ‘$KABOOM_CUR_STAGE’."
}

make_build() {
	local NPROC=$(nproc)
	NPROC=$(( $NPROC + 1))
	if bool "$NOPARALLEL" ; then
		abinfo "Parallel build is disabled."
		NPROC=1
	fi
	if [ ! -e "$PWD"/Makefile ] ; then
		abdie "Makefile not found."
	fi
	make -j"$NPROC" "$@" || \
		abdie "Failed to build ‘$PKGNAME-$PKGVER’ during sequence ‘$KABOOM_CUR_STAGE’."
}

make_install_tools() {
	make install "$@" || \
		abdie "Failed to install ‘$PKGNAME-$PKGVER’ into the toolchain directory."
}

make_install_native() {
	make install DESTDIR="$KABOOM_CUR_SYSROOT" "$@" || \
		abdie "Failed to install ‘$PKGNAME-$PKGVER’ into current system root."
}

cmake_native() {
	local c="$PWD"
	local src="$1"
	local bld="$2"
	shift 2
	if [ -z "$1" ] || [ -z "$2" ] ; then
		abdie "Usage: $0 SRCDIR BLDDIR"
	fi
	abinfo "CMake: using source directory $src"
	abinfo "CMake: using build directory $bld"
	if [ "$1" = "--" ] ; then
		shift 1
	fi
	if ! [ -f "$src"/CMakeLists.txt ] ; then
		abdie "Can not find CMakeLists.txt!"
	fi
	cmake -S "$src" -B "$bld" \
		"${KABOOM_CMAKE_NATIVE_DEF[@]}" \
		"${ARCH_DEF[@]}" \
		"$@" || abdie \
		"CMake configuration failed for ‘$PKGNAME-$PKGVER’."
}

cmake_build() {
	local bld="$1"
	shift 1

	if [ "$1" = "--" ] ; then
		shift 1
	fi
	cmake --build "$bld" "$@" || {
		abdie "Failed to build ‘$PKGNAME-$PKGVER’ with CMake."
	}
}

cmake_install() {
	local bld="$1"
	shift 1

	if [ "$1" = "--" ] ; then
		shift 1
	fi
	cmake --install "$bld" "$@" || {
		abdie "Failed to install ‘$PKGNAME-$PKGVER’ with CMake."
	}
}

execute_sequence() {
	local sequence="$KABOOM_CUR_STAGE" entry entry2 script package name continued=0 total index=1
	if [ ! -e "$KABOOM_TOP/sequence/$KABOOM_CUR_STAGE" ] ; then
		abdie "Sequence file for stage ‘$KABOOM_CUR_STAGE’ does not exist."
	fi
	IFS=$'\n'
	sequence=($(cat "$KABOOM_TOP/sequence/$sequence"))
	mkdir -p "$KABOOM_BUILD_DIR"/"$KABOOM_CUR_STAGE"
	unset IFS
	total="${#sequence[@]}"
	for entry in "${sequence[@]}" ; do
		if [ "${entry###}" != "$entry" ] ; then
			# a comment line
			continue
		fi
		entry2=($entry)
		package="${entry2[0]}"
		if [ -n "$KABOOM_CONTINUE_PACKAGE" ] ; then
			if ! bool "$continued" && \
 				[ "$KABOOM_CONTINUE_PACKAGE" != "$package" ] ; then
				continue
			fi
		fi
		continued=1
		name="${entry2[1]}"
		if [ -z "$name" ] ; then
			CUR_WORKSPACE="$KABOOM_BUILD_DIR"/"$KABOOM_CUR_STAGE"/"$package"
			script="$KABOOM_TOP/packages/$package/$KABOOM_CUR_STAGE"
		else
			CUR_WORKSPACE="$KABOOM_BUILD_DIR"/"$KABOOM_CUR_STAGE"/"$package"-"$name"
			script="$KABOOM_TOP/packages/$package/$KABOOM_CUR_STAGE-$name"
		fi
		if [ ! -f "$script" ] ; then
			abdie "Build script ‘$(basename $script)’ for package ‘$package’ does not exist."
		fi
		if [ -e "$CUR_WORKSPACE" ] ; then
			abinfo "Build directory already exists. Removing ..."
			rm -rf "$CUR_WORKSPACE"
		fi
		mkdir -pv "$CUR_WORKSPACE"
		PKGNAME="$package"
		PKGSPEC="$KABOOM_TOP/packages/$package/spec"
		PKGVER="$(source $PKGSPEC ; echo $VER)"
		abinfo "Building $PKGNAME-$PKGVER ..."
		set_title "[$KABOOM_CUR_STAGE] [$index/$total] $PKGNAME"
		checkout_srcs "$PKGSPEC"
		pushd "$CUR_WORKSPACE"
		ARCH_DEF=()
		# Run this job in a subshell to prevent unexpected behaviors.
		( source "$script" ) || {
			abdie "Failed to build package ‘$package’."
		}
		popd
		abinfo "Finished building ‘$PKGNAME-$PKGVER’."
		index=$(( $index + 1 ))
		unset CUR_WORKSPACE PKGNAME PKGVER PKGSPEC ARCH_DEF
	done
}
