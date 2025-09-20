MAINLINE_ARCHS=(
	amd64 arm64 loongarch64 loongson3 ppc64el riscv64
)

RETRO_ARCHS=(
	alpha armv4 armv6hf armv7hf i486 ia64 loongson2f m68k powerpc ppc64
)
ab_match_arch() {
	[ "$1" = "$KABOOM_TARGET_ARCH" ]
}

ab_match_archgroup() {
	local group="$1"
	local all_arch var="${group^^}_ARCHS[*]"
	all_arch=" ${!var} "
	[ "${all_arch// $KABOOM_TARGET_ARCH /}" != "${all_arch}" ]
}

# Sets ARCH_DEF array to the expanded value.
# This is useful if you define package-specific flags that can be appeneded
# to the build script, such as:
#
# GCC_TOOLS_DEF__I486=(
# 	"--with-cpu=i486"
# 	"--with-tune=pentium2"
# )
#
# And add this in your GCC build script:
#	expand_arch_def
#
# So that becomes:
# [...]
# # Fetch arch specific definitions
# expand_arch_def
# # The fetched ARCH_DEF will be automatically appended, before the
# arguments specified:
# configure_tools "--enable-default-ssp"
# # This results in:
# ../configure [...] --with-cpu=i486 --with-tune=pentium2 \
# 	--enable-default-ssp
# You MUST set ${PKGNAME^^}_${KABOOM_CUR_STAGE^^}_DEF__$KABOOM_TARGET_ARCH in targets/$KABOOM_TARGET_ARCH!
expand_arch_def() {
	local var
	var="${PKGNAME^^}_${KABOOM_CUR_STAGE^^}_DEF__${KABOOM_TARGET_ARCH^^}[@]"
	ARCH_DEF=("${!var}")
}
