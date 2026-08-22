#!/bin/bash
set -e
if [ -z "$ABBS" ] ; then
	echo "[!] Usage: env ABBS=/path/to/abbs $0"
	exit 1
fi
if [ ! -d "$ABBS" ] ; then
	echo "[!] ABBS path $ABBS is not a directory."
	exit 1
fi
echo "[+] Updating ABBS ..."
pushd "$ABBS"
if ! git diff --quiet ; then
	echo "[!] ABBS tree $ABBS is dirty."
	exit 1
fi
git checkout -f stable
git pull
pushd

declare -A pkgdirs
pkgs=()
for p in packages/* ; do
	if [ ! -f "$p"/spec ] ; then
		continue
	fi
	pkgname=${p##packages/}
	pkgname=${pkgname%%/*}
	pkgdirs["${pkgname}"]="$p"/spec
	pkgs+=("$pkgname")
done

method_change_pkgs=()
changed_pkgs=()

echo "[+] Found ${#pkgs[@]} packages."

for pkg in "${pkgs[@]}" ; do
	abbsdir=$(find $ABBS -mindepth 2 -maxdepth 2 -type d -name $pkg)
	if [ ! -d "$abbsdir" ] ; then
		continue
	fi
	. ${pkgdirs[$pkg]}
	KABOOM_VER=$VER
	KABOOM_SRCS=("${SRCS[@]}")
	KABOOM_CHKSUMS=("${CHKSUMS[@]}")
	unset UPSTREAM_VER VER SRCS CHKSUMS CHKUPDATE
	. $abbsdir/spec
	if [ -n "$UPSTREAM_VER" ] ; then
		ABBS_VER="$UPSTREAM_VER"
	else
		ABBS_VER="$VER"
	fi
	ABBS_SRCS=($SRCS)
	ABBS_CHKSUMS=($CHKSUMS)
	if [ "${ABBS_VER/$KABOOM_VER}" != "$ABBS_VER" ] ; then
		continue
	fi
	echo "$pkg requires update."
	echo "Version in AOSC OS: $ABBS_VER"
	echo "Version in Kaboom:  $KABOOM_VER"
	sed -i -e 's/^VER.*/VER='"$ABBS_VER"'/' "${pkgdirs[$pkg]}"
	entry=(${KABOOM_CHKSUMS[0]})
	OLD_CHKSUM="${entry[1]}"
	OLD_METHOD="${KABOOM_SRCS[0]}"
	entry=($OLD_METHOD)
	OLD_METHOD="${entry[0]}"
	NEW_METHOD="${ABBS_SRCS[0]}"
	NEW_METHOD="${NEW_METHOD%%::*}"
	if [ "$NEW_METHOD" == "${ABBS_SRCS[0]}" ] ; then
		NEW_METHOD="tbl"
	fi
	if [ "$OLD_METHOD" != "$NEW_METHOD" ] && \
		[ "$OLD_METHOD" != "git" ] ; then
		echo "Old method: $OLD_METHOD"
		echo "New method: $NEW_METHOD"
		method_change_pkgs+=("$pkg")
	else
		changed_pkgs+=("$pkg")
	fi

	if [  "${OLD_METHOD}${NEW_METHOD}" = "tbltbl" ]; then
		NEW_CHKSUM="${ABBS_CHKSUMS[0]}"
		NEW_CHKSUM="${NEW_CHKSUM##*::}"
		echo "Old checksum: $OLD_CHKSUM"
		echo "New checksum: $NEW_CHKSUM"
		sed -i -e "s,$OLD_CHKSUM,$NEW_CHKSUM," "${pkgdirs[$pkg]}"
	fi
	unset UPSTREAM_VER VER SRCS CHKSUMS CHKUPDATE
done

if [ "${#method_change_pkgs[@]}" -gt "0" ] ; then
	echo "The checksum of following packages are not updated:"
	echo "  ${method_change_pkgs[@]}"
	echo "Please update the checksum manually or switch to Git."
fi

cat << EOF
You can run the following command to commit your changes:

for p in ${changed_pkgs[*]} ; do
	source packages/\$p/spec
	git commit -m "\$p: update to \$VER" packages/\$p
done
EOF
