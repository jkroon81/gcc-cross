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

TARGET ?= h8300-elf
HOST ?= mingw64

configure_flags_mingw64 := --build=x86_64-pc-linux-gnu --host=x86_64-w64-mingw32

define configure_flags
$(configure_flags_$1) \
--target=$(TARGET) \
--disable-nls \
--prefix=$(CURDIR)/$(TARGET)-toolchain-$1
endef

gcc_unpack_hook := \
	cd gcc-$(gcc_version) && \
	./contrib/download_prerequisites

all : .stamp.binutils-$(TARGET)-$(HOST) .stamp.gcc-$(TARGET)-$(HOST)

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

define add_host
.stamp.binutils-$1-$2 : binutils-$$(binutils_version)
	rm -rf binutils-build-$1-$2
	mkdir binutils-build-$1-$2
	cd binutils-build-$1-$2 && \
	../binutils-$$(binutils_version)/configure \
		$$(call configure_flags,$2) && \
	make && \
	make install-strip
	touch $$@

ifeq ($2,linux)
.stamp.gcc-bootstrap-$1 : gcc-$$(gcc_version) .stamp.binutils-$1-$2
	rm -rf gcc-bootstrap-build-$1
	mkdir gcc-bootstrap-build-$1
	cd gcc-bootstrap-build-$1 && \
	../gcc-$$(gcc_version)/configure \
		$$(call configure_flags,$2) \
		--enable-languages=c \
		--with-newlib && \
	make all-gcc && \
	make install-gcc
	touch $$@

.stamp.newlib-$1-$2 : .stamp.gcc-bootstrap-$1
else
.stamp.newlib-$1-$2 : .stamp.gcc-$1-linux
endif

.stamp.newlib-$1-$2 : newlib-$(newlib_version)
	rm -rf newlib-build-$1-$2
	mkdir newlib-build-$1-$2
	export PATH=$$(CURDIR)/$1-toolchain-linux/bin:$$(PATH) && \
	cd newlib-build-$1-$2 && \
	../newlib-$$(newlib_version)/configure \
		$$(call configure_flags,$2) \
		--disable-newlib-supplied-syscalls && \
	make && \
	make install
	touch $$@

.stamp.gcc-$1-$2 : gcc-$$(gcc_version) .stamp.newlib-$1-$2
	rm -rf gcc-build-$1-$2
	mkdir gcc-build-$1-$2
	export PATH=$$(CURDIR)/$1-toolchain-linux/bin:$$(PATH) && \
	cd gcc-build-$1-$2 && \
	../gcc-$$(gcc_version)/configure \
		$$(call configure_flags,$2) \
		--enable-languages=c \
		--with-newlib && \
	make && \
	make install-strip
	touch $$@
endef

$(foreach h,$(hosts),$(eval $(call add_host,$(TARGET),$h)))

clean :
	rm -f .stamp.*
	rm -rf binutils-build-* gcc*-build-* newlib-build-*
	rm -rf *-toolchain-*
