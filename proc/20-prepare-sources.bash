if bool "$KABOOM_SKIP_DL_SOURCES" ; then
	return 0
fi

echo "
=======================================
Downloading source files
=======================================
"

source "$KABOOM_TOP"/helpers/download-sources
