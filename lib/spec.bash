#!/bin/bash

# NOTE:
# Source specification syntax:
# VER=2.41
# SRCS=(
# 	"TYPE [RENAME] URL"
# 	"tbl [default] https://ftpmirror.gnu.org/gnu/glibc/glibc-${VER}.tar.xz"
# )
# CHKSUMS=(
# 	"TYPE HASH"
# )
# SRCS__ARCH=(
# 	[...]
# )
# CHKSUMS__ARCH=(
# 	[...]
# )

has_arch_specific_srcs() {
	local var="SRCS_${KABOOM_ARCH^^}[*]"
	[ -n "${!var}" ]
}

get_pkgmetadata_dir() {
	local pkgname="$PKGNAME"
	if [ -z "$pkgname" ] ; then
		if [ -z "$1" ] ; then
			abdie "$0: Invalid usage"
		fi
		pkgname="$1"
	fi
	realpath "$KABOOM_TOP/packages/$pkgname"
}

# $1: full path to the spec file.
# $2: command to execute. The commans will be executed in a subshell, arguments are:
# 	COMMAND srctype srcname url chksum_algo chksum_name
# NOTE: chksum_value will be the git commit if the source is a git repository.
for_each_srcs() {
(
	local index
	local val="SRCS[@]" val2="CHKSUMS[@]"
	local src_entry
	local spec_file="$1"
	local pkgname="$(dirname "$spec_file")"
	if [ ! -e "$spec_file" ] ; then
		abdie "Specification $spec_file does not exist."
	fi
	. "$spec_file"
	pkgname="$(basename "$pkgname")"
	if declare -p "SRCS__${KABOOM_ARCH^^}" &>/dev/null ; then
		val="SRCS__${KABOOM_ARCH^^}[@]"
		val2="CHKSUMS__${KABOOM_ARCH^^}[@]"
	fi
	local real_srcs=("${!val}")
	local real_chksums=("${!val2}")
	index=0
	for src in "${real_srcs[@]}" ; do
		src_entry=($src)
		if [ "${srctype//@(tbl|file)}" != "$srctype" ] && [ "${#src_entry[@]}" != 3 ] ; then
			aberr "Invalid source entry: ‘$src’. Tarball and file entries should have 3 components:"
			aberr "    \"SRCTYPE SRCURL RENAME\""
			abdie "Where RENAME is either ‘default’ or a specified value."
		elif [ "${srctype//git}" != "$srctype" ] && [ "${#src_entry[@]}" != 4 ] ; then
			aberr "Invalid source entry: ‘$src’. Git entries should have 4 components:"
			aberr "    \"SRCTYPE SRCURL RENAME COMMIT\""
			abdie "Where RENAME is either ‘default’ or a specified value."
		fi

		rename="default"
		srctype="${src_entry[0]}"
		url="${src_entry[1]}"
		urlscheme="${url%%:*}"
		rename="${src_entry[2]}"
		if [ "$srctype" = "git" ] ; then
			commit="${src_entry[3]}"
		fi
		if [ "$rename" = "default" ] ; then
			if [ "$srctype" = "tbl" ] ; then
				srcname="$pkgname-$VER"
				if [ "${url%%.tar*}" != "${url}" ] ; then
					srcname="$srcname.tar${url##*.tar}"
				elif [ "${url%%.zip}" != "${url}" ] ; then
					srcname="$srcname.zip"
				fi
			elif [ "$srctype" = "file" ] ; then
				srcname="${url##*/}"
				srcname="${srcname%%\?*}"
				if [ -z "$srcname" ] ; then
					abdie "URL ‘$url’ does not contain a valid filename."
				fi
			else
				srcname="$pkgname.git"
			fi
		else
			srcname="$rename"
		fi
		if [ "$srctype" = "tbl" ] || [ "$srctype" = "file" ] ; then
			# Find the respective checksum
			chksum_entry=(${real_chksums[$index]})
			chksum_algo=${chksum_entry[0]}
			chksum_val=${chksum_entry[1]}
		else
			chksum_algo="SKIP"
			chksum_val="$commit"
		fi
		"$2" "$srctype" "$srcname" "$url" \
			"$chksum_algo" "$chksum_val" || \
			abdie "Command ‘$2’ failed when processing $pkgname: ‘$src’."
		index=$(( $index + 1 ))
	done
)
}

unpack_src() {
	pushd "$2"
	case "$1" in
		*.tar*)
			tar xf "$1"
			;;
		*.zip)
			unzip "$1"
			;;
	esac
	popd
}

_checkout_src() {
	case "$1" in
		tbl)
			abinfo "Unpacking ‘$2’ ..."
			unpack_src "$KABOOM_DL_DIR"/"$2" \
				"$CUR_WORKSPACE"
			;;
		file)
			abinfo "Copying file ‘$2’ ..."
			cp -v "$KABOOM_DL_DIR"/"$2" \
				"$CUR_WORKSPACE"/"$2"
			;;
		git)
			abinfo "Checking out repository ‘$2’ ..."
			git clone "$KABOOM_DL_DIR"/"$2" \
				"$CUR_WORKSPACE"/"$2"
			pushd "$CUR_WORKSPACE"/"$2"
			git checkout "$5" || abdie \
				"Failed to checkout source ‘$2’ to ‘$5’."
			popd
			;;
	esac
}

checkout_srcs() {
	if [ -z "$CUR_WORKSPACE" ]; then
		abdie "Expected CUR_WORKSPACE to be set."
	fi
	# CUR_WORKSPACE is:
	# $KABOOM_BUILD_DIR/$STAGE/$PKG
	# Checked out sources will be inside this directory.
	abinfo "Checking out source files ..."
	local restore_dir=0
	if [ "$PWD" != "$CUR_WORKSPACE" ] ; then
		restore_dir=1
		pushd "$CUR_WORKSPACE"
	fi
	for_each_srcs "$1" _checkout_src
	[ "$restore_dir" = "1" ] && popd
}

# $1: full path to the file.
# $2: algorithm.
hash_file() {
	local file="$1"
	local algo="$2"
	case "${algo,,}" in
		md5|sha1|sha256|sha384|sha512)
			hash=($(openssl $algo -r "$file"))
			;;
		*)
			abdie "Unknown hash algorithm ‘$algo’."
			;;
	esac
	if [ "${#hash[@]}" -lt 1 ] ; then
		abdie "Internal error - hash value is empty."
	fi
	echo "${hash[0]}"
}

# $1: srcname
# $2: hash algorithm
# $3: hash value
verify_source() {
	local dl_dir="$KABOOM_TOP"/sources
	local file="$1"
	local hash_algo="$2"
	local expected="$3"
	# If the file does not exist, return false (triggers the download).
	if [ ! -e "$dl_dir"/"$file" ] ; then
		abinfo "Source code ‘$file’ does not exist yet, downloading ..."
		return 1
	fi
	if [ "$hash_algo" = "SKIP" ] ; then
		return 0
	fi
	file="$dl_dir"/"$file"
	hash_value=($(hash_file "$file" "$hash_algo"))

	if [ "${hash_value[0]}" != "$expected" ] ; then
		abdie "Error: hash value mismatch ($hash_algo) !\n\tExpected: $expected\n\tActual: ${hash_value[0]}"
	fi
	return 0
}

download_file() {
	local dl_dir="$KABOOM_TOP"/sources
	wget -O "$dl_dir"/"$2" "$1"
}

git_bare_clone() {
	local dl_dir="$KABOOM_TOP"/sources
	git clone --bare "$1" "$dl_dir"/"$2"
}

download_source() {
	local srctype="$1"
	local srcname="$2"
	local srcurl="$3"
	case "$srctype" in
		tbl|file)
			download_file "$srcurl" "$srcname"
			;;
		git)
			git_bare_clone "$srcurl" "$srcname"
			;;
		*)
			abdie "Unknown source type ‘$srctype’."
			;;
	esac
}

verify_and_download() {
	local dl_dir="$KABOOM_TOP"/sources
	local srctype="$1"
	local srcname="$2"
	local srcurl="$3"
	local chksum_algo="$4"
	local chksum_val="$5"
	if ! verify_source "$srcname" "$chksum_algo" "$chksum_val" ; then
		if [ -f "$dl_dir"/"$srcname" ] ; then
			rm -f "$dl_dir"/"$srcname"
		fi
		if [ -d "$dl_dir"/"$srcname" ] ; then
			rm -rf "$dl_dir"/"$srcname"
		fi
		download_source "$srctype" "$srcname" "$srcurl"
	fi
	abinfo "Verifying integrity of source file ‘$srcname’ ..."
	verify_source "$srcname" "$chksum_algo" "$chksum_val"
	abinfo "Checksum verified."
	if [ "$srctype" = "git" ] ; then
		abinfo "$srcname: Upadting Git repository ..."
		git --git-dir="$dl_dir"/"$srcname" \
			fetch --tags --all
	fi
}


