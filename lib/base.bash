#!/bin/bash

set -e

# Output formatters.
abwarn() { echo -e "[\e[33mWARN\e[0m]: \e[1m$*\e[0m"; }
aberr()  { echo -e "[\e[31mERROR\e[0m]: \e[1m$*\e[0m"; KABOOM_ERROR=1; }
abinfo() { echo -e "[\e[96mINFO\e[0m]: \e[1m$*\e[0m"; }

# see if the given string evaluates into true.
bool() {
	local v="$1"
	[ -z "$v" ] && return 1
	[[ "${v,,}" =~ y|yes|1|true ]]
}

# If the terminal allows, set a title.
set_title() {
	if [ "${TERM//xterm/}" == "$TERM" ] ; then
		return
	fi
	echo -ne "\e]0;[kaboom] $@\007\r"
}

ab_match_arch() {
	if [ "$1" = "mainline" ] || \
		[ "$1" = "retro" ] ; then
		local all_arch var="$1[*]"
		all_arch=" ${!var} "
		[ "${all_arch// $KABOOM_TARGET_ARCH /}" != "${all_arch}" ]
	else
		[ "$1" = "$KABOOM_TARGET_ARCH" ]
	fi
}

abdie() {
	echo -e "[\e[31mERROR\e[0m]: \e[1m$*\e[0m"
	set_title "Failed at $KABOOM_CUR_STAGE $PKGNAME"
	exit 1
}
