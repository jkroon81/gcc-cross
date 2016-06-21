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
archs := linux mingw64

HOST ?= linux

configure_flags_mingw64 := \
--build=x86_64-pc-linux-gnu \
--host=x86_64-w64-mingw32
define configure_flags
$(configure_flags_$1) \
--target=h8300-elf \
--disable-nls \
--prefix=$(CURDIR)/out-$1
endef

gcc_unpack_hook := \
	cd gcc-$(gcc_version) && \
	./contrib/download_prerequisites

all : .stamp.gcc-full-$(HOST)

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

define add_arch
.stamp.binutils-$1 : binutils-$$(binutils_version)
	rm -rf binutils-build-$1
	mkdir binutils-build-$1
	cd binutils-build-$1 && \
	../binutils-$$(binutils_version)/configure \
		$$(call configure_flags,$1) && \
	make && \
	make install-strip
	touch $$@

ifeq ($1,linux)
.stamp.gcc-$1 : gcc-$$(gcc_version) .stamp.binutils-$1
	rm -rf gcc-build-$1
	mkdir gcc-build-$1
	cd gcc-build-$1 && \
	../gcc-$$(gcc_version)/configure \
		$$(call configure_flags,$1) \
		--enable-languages=c \
		--with-newlib && \
	make all-gcc && \
	make install-gcc
	touch $$@
endif

.stamp.newlib-$1 : newlib-$(newlib_version) .stamp.gcc-linux
	rm -rf newlib-build-$1
	mkdir newlib-build-$1
	export PATH=$$(PATH):$$(CURDIR)/out-linux/bin && \
	cd newlib-build-$1 && \
	../newlib-$$(newlib_version)/configure \
		$$(call configure_flags,$1) \
		--disable-newlib-supplied-syscalls && \
	make && \
	make install
	touch $$@

.stamp.gcc-full-$1 : gcc-$$(gcc_version) .stamp.newlib-$1 .stamp.gcc-linux
	rm -rf gcc-full-build-$1
	mkdir gcc-full-build-$1
	export PATH=$$(PATH):$$(CURDIR)/out-linux/bin && \
	cd gcc-full-build-$1 && \
	../gcc-$$(gcc_version)/configure \
		$$(call configure_flags,$1) \
		--enable-languages=c \
		--with-newlib && \
	make && \
	make install-strip
	touch $$@
endef

$(foreach a,$(archs),$(eval $(call add_arch,$a)))

clean :
	rm -f .stamp.*
	rm -rf binutils-build-* gcc-build-* newlib-build-*
	rm -rf out-*
