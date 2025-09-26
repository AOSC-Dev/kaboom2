# kaboom

Kaboom is a tool to bootstrap AOSC OS stage 1 from a (sane) Linux environment. It is completely rootless with `fakeroot`, so you can run it anywhere.

## Requirements

- Host GCC and binutils
- GNU Bash, 5.0 and up
- CMake
- `fakeroot`
- Header and other development files for the following packages:
    - GCC and Binutils: `gmp`, `mpfr`
    - Python 3: `zlib`, `expat`, `libffi`, `openssl`
    - Dependencies to build `file`, `gettext`, and `pkgconf`
- Decent network connection
- Decent amount of free disk space
- Patience

## Usage

The only argument required is the target architecture:

```
git clone https://github.com/AOSC-Dev/kaboom
cd kaboom
./kaboom ARCH
```

For a list of available architectures, please see `targets/` in the source tree.

### Continue from a failed run

To aid the development, kaboom comes with a continuation feature. You can specify `-c stage/package` to continue from the package that previously failed after attempting to fix the error:

```
./kaboom -c stage0/gcc ia64
```

### Build with a debugable glibc

This sysroot ships with GDB. To aid development and debugging, you can build the target glibc with debug symbols:

```
./kaboom --debug-libc ia64
```

## Output

The final sysroot will be archived using tar and compressed using xz, with filename like `kaboom-stage1-$ARCH-$DATE.tar.xz`. The archive does not have any path prefix to the files. To extract, create a new directory with the root user and extract this archive from there:

```sh
sudo mkdir stage1-alpha
cd stage1-alpha
sudo tar xf ../kaboom-stage1-alpha-20251232.tar.xz
# Then you can enter the environment to build packages
sudo chroot $PWD
# Or...
sudo systemd-nspawn -D $PWD
```

## Adding a new target

Adding a new target involves the following steps:

1. Write a new target definition file at `target/YOURARCH` containing:
  - `KABOOM_TARGET_TRIPLE`: System triplet following GNU convention (the vendor must be `kaboom`, e.g. `mips64r6el-kaboom-linux-gnuabi64`).
  - `KABOOM_TARGET_CFLAGS`: C compiler flags for the target. Usually contains `-march=`, `-mcpu=` and `-mtune=`, sometimes other `-m` options are used to precisely control the generated code.
  - `KABOOM_TARGET_CXXFLAGS`: C++ compiler flags for the target. Mostly same as `CFLAGS`.
  - `KABOOM_TARGET_KERNEL_ARCH`: `ARCH=` option for the kernel. See `arch/` in the kernel tree for details.
  - `KABOOM_TARGET_ENDIANNESS`: Endianness of the target. Either `little` or `big`.
  - `KABOOM_TARGET_OPENSSL_TARGET`: Target option used to configure OpenSSL. See `Configurations/10-main.conf` in the OpenSSL source tree for details. If in doubt, say `"linux-generic(32|64) no-asm"` here.
2. Make a test run by running `./kaboom2 YOURARCH`.
3. `chroot` into your sysroot, run the following program:
  - `git clone`
  - `wget URL`
  - `curl URL`
4. Edit `/etc/autobuild/ab4cfg.sh`, replace your maintainer information, and specify `ARCH=` manually.
5. Build `bc` using `acbs-build bc:+stage2`.
6. If this build succeeded, then this architecture can be added into kaboom.

### Specifying target specific and package specific configure options

Sometimes the generic options used to configure a package is not enough. Configure options specific to this target must reside in the target specification file.

Target specific package overrides are specified with a Bash array, with the name like `PACKAGE_STAGE_DEF__ARCH`:

```bash
GLIBC_TOOLS_DEF__IA64=(
	"--disable-werror"
)
```

For example, for MIPS3 (loongson2f) machines the default `-march` option must be specified. To achieve this, add the following lines to `target/loongson2f`:

```bash
# Need to specify for both the host (cross-compile toolchain) and stage0 (cross-compiled) GCC
GCC_TOOLS_DEF__LOONGSON2F=(
	"--with-arch=mips3"
	"--with-tune=loongson2f"
)

GCC_STAGE0_DEF__LOONGSON2F=(
	"--with-arch=mips3"
	"--with-tune=loongson2f"
)
```
