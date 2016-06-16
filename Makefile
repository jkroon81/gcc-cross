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

all : build-packages

.PHONY : build-packages

build-packages : .stamp.build-binutils .stamp.build-gcc

define add_package
$1-$($1_version) : sources/$1-$$($1_version)$$($1_suffix)
	tar -xmf $$<

sources/$1-$$($1_version)$$($1_suffix) :
	mkdir -p sources && \
	cd sources && \
	wget $$($1_location)$$(notdir $$@)
endef

$(foreach p,$(packages),$(eval $(call add_package,$p)))

.stamp.build-binutils : binutils-$(binutils_version)
	rm -rf binutils-build
	mkdir binutils-build
	cd binutils-build && \
	../binutils-$(binutils_version)/configure \
		--target=h8300-elf \
		--prefix=$(CURDIR)/out && \
	make && \
	make install
	touch $@

.stamp.build-gcc : gcc-$(gcc_version) newlib-$(newlib_version)
	cd gcc-$(gcc_version) && ln -sf ../newlib-$(newlib_version) newlib
	rm -rf gcc-build
	mkdir gcc-build
	cd gcc-build && \
	../gcc-$(gcc_version)/configure \
		--target=h8300-elf \
		--prefix=$(CURDIR)/out \
		--enable-languages=c \
		--with-newlib && \
	make all-gcc && \
	make install-gcc
	touch $@
