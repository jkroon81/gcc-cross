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

hosts := x86_64-pc-linux-gnu x86_64-w64-mingw32
njobs := $(shell echo "2 * `cat /proc/cpuinfo | grep processor | wc -l`" | bc)

BUILD ?= x86_64-pc-linux-gnu
HOST ?= x86_64-w64-mingw32
TARGET ?= h8300-elf

define cf_binutils_x86_64-w64-mingw32-$(BUILD)
--with-sysroot=$(CURDIR)/sysroots/$2/$1/sys-root
endef

define cf_binutils_$(TARGET)-x86_64-w64-mingw32
--build=$(BUILD) \
--host=$2
endef

define cf_binutils
$(call cf_binutils_$1-$2,$1,$2) \
--prefix=$(CURDIR)/sysroots/$2 \
--target=$1
endef

define cf_gcc_$(TARGET)-x86_64-w64-mingw32
--build=$(BUILD) \
--host=$2
endef

define cf_gcc_$(TARGET)
--enable-languages=c \
--with-newlib
endef

define cf_gcc_x86_64-w64-mingw32
--enable-languages=c,c++ \
--with-sysroot=$(CURDIR)/sysroots/$2/$1/sys-root
endef

define cf_gcc
$(call cf_gcc_$1-$2,$1,$2) \
$(call cf_gcc_$1,$1,$2) \
--disable-decimal-float \
--disable-libquadmath \
--disable-libssp \
--prefix=$(CURDIR)/sysroots/$2 \
--target=$1
endef

define cf_newlib_$(TARGET)-x86_64-w64-mingw32
--build=$(BUILD) \
--host=$2
endef

define cf_newlib
$(call cf_newlib_$1-$2,$1,$2) \
--prefix=$(CURDIR)/sysroots/$2 \
--disable-newlib-supplied-syscalls \
--target=$1
endef

define cf_mingw
--build=$(BUILD) \
--host=$1 \
--prefix=$(CURDIR)/sysroots/$2/$1/sys-root/mingw
endef

gcc_unpack_hook := cd gcc-$(gcc_version) && ./contrib/download_prerequisites

all : $(TARGET)-toolchain.tar.gz

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
	export PATH=$$(CURDIR)/sysroots/$(BUILD)/bin:$$(PATH) && \
	../binutils-$$(binutils_version)/configure \
		$$(call cf_binutils,$1,$2) && \
	make -j $(njobs) && \
	make install-strip
	touch $$@

ifeq ($2,$(HOST))
.stamp.binutils-$1-$2 : .stamp.gcc-$(HOST)-$(BUILD)
endif

ifeq ($2,$(BUILD))
.stamp.gcc-bootstrap-$1 : .stamp.gcc-unpack .stamp.binutils-$1-$2
	$$(call prep_build,gcc-$1-$2) && \
	../gcc-$$(gcc_version)/configure \
		$$(call cf_gcc,$1,$2) && \
	make all-gcc -j $(njobs) && \
	make install-gcc
	touch $$@

.stamp.newlib-$1-$2 : .stamp.gcc-bootstrap-$1
else
.stamp.newlib-$1-$2 : .stamp.gcc-$1-$(BUILD)
endif

.stamp.newlib-$1-$2 : .stamp.newlib-unpack
	$$(call prep_build,newlib-$1-$2) && \
	export PATH=$$(CURDIR)/sysroots/$(BUILD)/bin:$$(PATH) && \
	../newlib-$$(newlib_version)/configure \
		$$(call cf_newlib,$1,$2) && \
	make -j $(njobs) && \
	make install-strip
	touch $$@

.stamp.mingw-w64-headers-$1-$2 : .stamp.mingw-w64-unpack
	$$(call prep_build,mingw-w64-headers-$1-$2) && \
	../mingw-w64-$(mingw-w64_version)/mingw-w64-headers/configure \
		$$(call cf_mingw,$1,$2) && \
	make install
	touch $$@

.stamp.mingw-w64-$1-$2 : .stamp.mingw-w64-headers-$1-$2 .stamp.gcc-bootstrap-$1
	$$(call prep_build,mingw-w64-$1-$2) && \
	export PATH=$$(CURDIR)/sysroots/$(BUILD)/bin:$$(PATH) && \
	../mingw-w64-$(mingw-w64_version)/configure \
		$$(call cf_mingw,$1,$2) && \
	make -j $(njobs) && \
	make install-strip
	touch $$@

ifeq ($1,x86_64-w64-mingw32)
.stamp.gcc-$1-$2 : .stamp.mingw-w64-$1-$2
else
.stamp.gcc-$1-$2 : .stamp.newlib-$1-$2
endif

ifeq ($2,$(BUILD))
.stamp.gcc-$1-$2 : .stamp.gcc-unpack
	cd gcc-$1-$2 && \
	export PATH=$$(CURDIR)/sysroots/$(BUILD)/bin:$$(PATH) && \
	make -j $(njobs) && \
	make install-strip
	touch $$@
else
.stamp.gcc-$1-$2 : .stamp.gcc-unpack
	$$(call prep_build,gcc-$1-$2) && \
	export PATH=$$(CURDIR)/sysroots/$(BUILD)/bin:$$(PATH) && \
	../gcc-$$(gcc_version)/configure \
		$$(call cf_gcc,$1,$2) && \
	make -j $(njobs) && \
	make install-strip
	touch $$@
endif

endef

$(foreach h,$(hosts),$(eval $(call add_toolchain,$(TARGET),$h)))
$(eval $(call add_toolchain,$(HOST),$(BUILD)))

$(TARGET)-toolchain.tar.gz : .stamp.binutils-$(TARGET)-$(HOST) \
                             .stamp.gcc-$(TARGET)-$(HOST)
	cd sysroots && tar -czf ../$@ $(HOST)

clean :
	rm -f .stamp.*
	rm -rf binutils-* gcc-* newlib-* mingw-w64-*
	rm -rf sysroots
	rm -f *-toolchain.tar.gz
