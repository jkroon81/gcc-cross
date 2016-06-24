packages := binutils gcc newlib mingw-w64
binutils_version := 2.26
binutils_suffix := .tar.bz2
binutils_location := http://ftp.gnu.org/gnu/binutils/
gcc_version := 6.1.0
gcc_suffix := .tar.bz2
gcc_location := ftp://ftp.fu-berlin.de/unix/languages/gcc/releases/gcc-6.1.0/
newlib_version := 2.4.0
newlib_suffix := .tar.gz
newlib_location := ftp://sourceware.org/pub/newlib/
mingw-w64_version := v4.0.6
mingw-w64_suffix := .tar.bz2
mingw-w64_location := http://sourceforge.mirrorservice.org/m/mi/mingw-w64/mingw-w64/mingw-w64-release/

hosts := linux mingw-w64
njobs := $(shell echo "2 * `cat /proc/cpuinfo | grep processor | wc -l`" | bc)


TARGET ?= h8300-elf
HOST ?= mingw-w64

configure_flags_mingw-w64 := --build=x86_64-pc-linux-gnu --host=x86_64-w64-mingw32

define configure_flags
$(configure_flags_$2) \
--prefix=$(CURDIR)/$1-$2 \
--target=$1 \
CFLAGS='-O2' \
CFLAGS_FOR_TARGET='-Os -fomit-frame-pointer' \
CXXFLAGS='-O2' \
CXXFLAGS_FOR_TARGET='-Os -fomit-frame-pointer'
endef

configure_flags_gcc := \
	--disable-decimal-float \
	--disable-libquadmath \
	--disable-libssp \
	--enable-languages=c \
	--with-newlib

gcc_unpack_hook := cd gcc-$(gcc_version) && ./contrib/download_prerequisites

all : $(TARGET)-toolchain-$(HOST).tar.gz

define add_package
.stamp.$1-unpack : sources/$1-$$($1_version)$$($1_suffix)
	rm -rf $1-$$($1_version)
	tar -xf $$<
	$$($1_unpack_hook)
	touch $$@

sources/$1-$$($1_version)$$($1_suffix) :
	mkdir -p sources && \
	cd sources && \
	wget $$($1_location)$$(notdir $$@)
endef

$(foreach p,$(packages),$(eval $(call add_package,$p)))

define prep_build
rm -rf $1 && mkdir $1 && cd $1
endef

define add_toolchain
.stamp.binutils-$1-$2 : .stamp.binutils-unpack
	$$(call prep_build,binutils-$1-$2) && \
	../binutils-$$(binutils_version)/configure \
		$$(call configure_flags,$1,$2) && \
	make -j $(njobs) && \
	make install-strip
	touch $$@

ifeq ($2,mingw-w64)
.stamp.binutils-$1-$2 : .stamp.gcc-x86_64-w64-mingw32-linux
endif

ifeq ($2,linux)
.stamp.gcc-bootstrap-$1 : .stamp.gcc-unpack .stamp.binutils-$1-$2
	$$(call prep_build,gcc-bootstrap-$1) && \
	../gcc-$$(gcc_version)/configure \
		$$(call configure_flags,$1,$2) \
		$$(configure_flags_gcc) && \
	make all-gcc -j $(njobs) && \
	make install-gcc
	touch $$@

.stamp.newlib-$1-$2 : .stamp.gcc-bootstrap-$1
else
.stamp.newlib-$1-$2 : .stamp.gcc-$1-linux
endif

.stamp.newlib-$1-$2 : .stamp.newlib-unpack
	$$(call prep_build,newlib-$1-$2) && \
	export PATH=$$(CURDIR)/$1-toolchain-linux/bin:$$(PATH) && \
	../newlib-$$(newlib_version)/configure \
		$$(call configure_flags,$1,$2) \
		--disable-newlib-supplied-syscalls && \
	make -j $(njobs) && \
	make install-strip
	touch $$@

.stamp.mingw-w64-headers-$1-$2 : .stamp.mingw-w64-unpack
	$$(call prep_build,mingw-w64-headers-$1-$2) && \
	../mingw-w64-$(mingw-w64_version)/mingw-w64-headers/configure \
		$$(call configure_flags,$1,$2) && \
	make install
	touch $$@

.stamp.mingw-w64-$1-$2 : .stamp.mingw-w64-headers-$1-$2
	$$(call prep_build,mingw-w64-$1-$2) && \
	../mingw-w64-$(mingw-w64_version)/configure \
		$$(call configure_flags,$1,$2)
	echo $$@

ifeq ($1,x86_64-w64-mingw32)
.stamp.gcc-$1-$2 : .stamp.mingw-w64-$1-$2
else
.stamp.gcc-$1-$2 : .stamp.newlib-$1-$2
endif

.stamp.gcc-$1-$2 : .stamp.gcc-unpack
	$$(call prep_build,gcc-$1-$2) && \
	export PATH=$$(CURDIR)/$1-toolchain-linux/bin:$$(PATH) && \
	../gcc-$$(gcc_version)/configure \
		$$(call configure_flags,$1,$2) \
		$$(configure_flags_gcc) && \
	make -j $(njobs) && \
	make install-strip
	touch $$@
endef

$(foreach h,$(hosts),$(eval $(call add_toolchain,$(TARGET),$h)))
$(eval $(call add_toolchain,x86_64-w64-mingw32,linux))

$(TARGET)-toolchain-$(HOST).tar.gz : .stamp.binutils-$(TARGET)-$(HOST) \
                                     .stamp.gcc-$(TARGET)-$(HOST)
	tar -czf $@ $(TARGET)-toolchain-$(HOST)

clean :
	rm -f .stamp.*
	rm -rf binutils-* gcc-* newlib-* mingw-w64-*
	rm -rf *-toolchain-*
