packages := binutils gcc newlib
binutils_version := 2.26
binutils_suffix := .tar.bz2
binutils_location := http://ftp.gnu.org/gnu/binutils/
gcc_version := 6.1.0
gcc_suffix := .tar.bz2
gcc_location := ftp://ftp.fu-berlin.de/unix/languages/gcc/releases/gcc-6.1.0/
newlib_version := 2.4.0
newlib_suffix := .tar.gz
newlib_location := ftp://sourceware.org/pub/newlib/
hosts := linux mingw64
njobs := $(shell echo "2 * `cat /proc/cpuinfo | grep processor | wc -l`" | bc)

TARGET ?= h8300-elf
HOST ?= mingw64

configure_flags_mingw64 := --build=x86_64-pc-linux-gnu --host=x86_64-w64-mingw32

define configure_flags
$(configure_flags_$1) \
--target=$(TARGET) \
--disable-nls \
--prefix=$(CURDIR)/$(TARGET)-toolchain-$1
endef

configure_flags_gcc := \
	--enable-languages=c \
	--with-newlib \
	--disable-libssp

gcc_unpack_hook := cd gcc-$(gcc_version) && ./contrib/download_prerequisites

all : $(TARGET)-toolchain-$(HOST).tar.gz

define add_package
$1-$($1_version) : sources/$1-$$($1_version)$$($1_suffix)
	rm -rf $$@
	tar -xmf $$<
	$$($1_unpack_hook)

sources/$1-$$($1_version)$$($1_suffix) :
	mkdir -p sources && \
	cd sources && \
	wget $$($1_location)$$(notdir $$@)
endef

$(foreach p,$(packages),$(eval $(call add_package,$p)))

define prep_build
rm -rf $1 && mkdir $1 && cd $1
endef

define add_host
.stamp.binutils-$1-$2 : binutils-$$(binutils_version)
	$$(call prep_build,binutils-$1-$2) && \
	../binutils-$$(binutils_version)/configure \
		$$(call configure_flags,$2) && \
	make -j $(njobs) && \
	make install-strip
	touch $$@

ifeq ($2,linux)
.stamp.gcc-bootstrap-$1 : gcc-$$(gcc_version) .stamp.binutils-$1-$2
	$$(call prep_build,gcc-bootstrap-$1) && \
	../gcc-$$(gcc_version)/configure \
		$$(call configure_flags,$2) \
		$$(configure_flags_gcc) && \
	make all-gcc -j $(njobs) && \
	make install-gcc
	touch $$@

.stamp.newlib-$1-$2 : .stamp.gcc-bootstrap-$1
else
.stamp.newlib-$1-$2 : .stamp.gcc-$1-linux
endif

.stamp.newlib-$1-$2 : newlib-$(newlib_version)
	$$(call prep_build,newlib-$1-$2) && \
	export PATH=$$(CURDIR)/$1-toolchain-linux/bin:$$(PATH) && \
	../newlib-$$(newlib_version)/configure \
		$$(call configure_flags,$2) \
		--disable-newlib-supplied-syscalls && \
	make -j $(njobs) && \
	make install-strip
	touch $$@

.stamp.gcc-$1-$2 : gcc-$$(gcc_version) .stamp.newlib-$1-$2
	$$(call prep_build,gcc-$1-$2) && \
	export PATH=$$(CURDIR)/$1-toolchain-linux/bin:$$(PATH) && \
	../gcc-$$(gcc_version)/configure \
		$$(call configure_flags,$2) \
		$$(configure_flags_gcc) && \
	make -j $(njobs) && \
	make install-strip
	touch $$@
endef

$(foreach h,$(hosts),$(eval $(call add_host,$(TARGET),$h)))

$(TARGET)-toolchain-$(HOST).tar.gz : .stamp.binutils-$(TARGET)-$(HOST) \
                                     .stamp.gcc-$(TARGET)-$(HOST)
	tar -czf $@ $(TARGET)-toolchain-$(HOST)

clean :
	rm -f .stamp.*
	rm -rf binutils-* gcc-* newlib-*
	rm -rf *-toolchain-*
