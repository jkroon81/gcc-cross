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

hosts := x86_64-redhat-linux x86_64-w64-mingw32
njobs := $(shell echo "2 * `cat /proc/cpuinfo | grep processor | wc -l`" | bc)

BUILD ?= x86_64-redhat-linux
HOST ?= x86_64-w64-mingw32
TARGET ?= h8300-elf

define cf_binutils_x86_64-w64-mingw32
--with-sysroot=$(CURDIR)/sysroots/$2/$1/sys-root
endef

define cf_binutils
--build=$(BUILD) \
--host=$2 \
--target=$1 \
--prefix=$(CURDIR)/sysroots/$2 \
--disable-dependency-tracking \
--disable-nls \
$(call cf_binutils_$1,$1,$2)
endef

define cf_gcc_$(TARGET)
--enable-languages=c \
--with-newlib \
CFLAGS_FOR_TARGET='-Os -fomit-frame-pointer' \
CXXFLAGS_FOR_TARGET='-Os -fomit-frame-pointer'
endef

define cf_gcc_x86_64-w64-mingw32
--enable-languages=c,c++ \
--with-sysroot=$(CURDIR)/sysroots/$2/$1/sys-root
endef

define cf_gcc
--build=$(BUILD) \
--host=$2 \
--target=$1 \
--prefix=$(CURDIR)/sysroots/$2 \
--disable-decimal-float \
--disable-libquadmath \
--disable-libssp \
--disable-nls \
$(call cf_gcc_$1,$1,$2)
endef

define cf_newlib
--build=$(BUILD) \
--host=$2 \
--target=$1 \
--prefix=$(CURDIR)/sysroots/$2 \
--disable-dependency-tracking \
--disable-newlib-supplied-syscalls \
--disable-nls \
CFLAGS_FOR_TARGET='-Os -fomit-frame-pointer' \
CXXFLAGS_FOR_TARGET='-Os -fomit-frame-pointer'
endef

define cf_mingw
--build=$(BUILD) \
--host=$1 \
--prefix=$(CURDIR)/sysroots/$2/$1/sys-root/mingw
endef

gcc_unpack_hook := \
cd gcc-$(gcc_version) && \
./contrib/download_prerequisites &> /dev/null

all : $(TARGET)-toolchain-$(HOST).tar.gz

define add_package
.stamp.$1-unpack : sources/$1-$$($1_version)$$($1_suffix)
	@echo "Unpacking $1"
	@rm -rf $1-$$($1_version)
	@tar -xf $$<
	@$$($1_unpack_hook)
	@touch $$@

sources/$1-$$($1_version)$$($1_suffix) :
	@echo "Downloading $1"
	@wget --quiet -P sources $$($1_location)$$(notdir $$@)
endef

$(foreach p,$(packages),$(eval $(call add_package,$p)))

define prep_build
@echo "Building $1($2) for $3" && \
rm -rf $1-$2-$3 && \
mkdir $1-$2-$3 && \
cd $1-$2-$3 && \
export PATH=$(CURDIR)/sysroots/$(BUILD)/bin:$$PATH
endef

define add_toolchain
.stamp.binutils-$1-$2 : .stamp.binutils-unpack
	$$(call prep_build,binutils,$1,$2) && \
	( ../binutils-$$(binutils_version)/configure \
		$$(call cf_binutils,$1,$2) && \
	make -j $(njobs) && \
	make install-strip ) &> $(CURDIR)/binutils-$1-$2.log
	@touch $$@

ifneq ($2-$(BUILD),$(BUILD)-$(BUILD))
.stamp.binutils-$1-$2 : .stamp.gcc-$2-$(BUILD)
endif

ifeq ($2,$(BUILD))
.stamp.gcc-bootstrap-$1 : .stamp.gcc-unpack .stamp.binutils-$1-$2
	$$(call prep_build,gcc,$1,$2) && \
	( ../gcc-$$(gcc_version)/configure \
		$$(call cf_gcc,$1,$2) && \
	make all-gcc -j $(njobs) && \
	make install-gcc ) &> $(CURDIR)/gcc-$1-$2.log
	@touch $$@

ifeq ($1,x86_64-w64-mingw32)
.stamp.gcc-bootstrap-$1 : .stamp.mingw-w64-headers-$1-$2
endif
endif

.stamp.newlib-$1-$2 : .stamp.newlib-unpack
	$$(call prep_build,newlib,$1,$2) && \
	( ../newlib-$$(newlib_version)/configure \
		$$(call cf_newlib,$1,$2) && \
	make -j $(njobs) && \
	make install-strip ) &> $(CURDIR)/newlib-$1-$2.log
	@touch $$@

ifeq ($2,$(BUILD))
.stamp.newlib-$1-$2 : .stamp.gcc-bootstrap-$1
else
.stamp.newlib-$1-$2 : .stamp.gcc-$1-$(BUILD)
endif

.stamp.mingw-w64-headers-$1-$2 : .stamp.mingw-w64-unpack .stamp.binutils-$1-$2
	$$(call prep_build,mingw-w64-headers,$1,$2) && \
	( ../mingw-w64-$(mingw-w64_version)/mingw-w64-headers/configure \
		$$(call cf_mingw,$1,$2) && \
	make install ) &> $(CURDIR)/mingw-w64-headers-$1-$2.log
	@touch $$@

.stamp.mingw-w64-crt-$1-$2 : .stamp.gcc-bootstrap-$1
	$$(call prep_build,mingw-w64-crt,$1,$2) && \
	( ../mingw-w64-$(mingw-w64_version)/mingw-w64-crt/configure \
		$$(call cf_mingw,$1,$2) && \
	make -j $(njobs) && \
	make install-strip ) &> $(CURDIR)/mingw-w64-crt-$1-$2.log
	@touch $$@

ifeq ($2,$(BUILD))
.stamp.gcc-$1-$2 :
	@echo "Continuing gcc($1) for $2"
	@(cd gcc-$1-$2 && \
	export PATH=$(CURDIR)/sysroots/$(BUILD)/bin:$$$$PATH && \
	make -j $(njobs) && \
	make install-strip ) >> gcc-$1-$2.log 2>&1
	@touch $$@
else
.stamp.gcc-$1-$2 : .stamp.gcc-unpack
	$$(call prep_build,gcc,$1,$2) && \
	( ../gcc-$$(gcc_version)/configure \
		$$(call cf_gcc,$1,$2) && \
	make -j $(njobs) && \
	make install-strip ) &> $(CURDIR)/gcc-$1-$2.log
	@touch $$@
endif

ifeq ($1,x86_64-w64-mingw32)
.stamp.gcc-$1-$2 : .stamp.mingw-w64-crt-$1-$2
else
.stamp.gcc-$1-$2 : .stamp.newlib-$1-$2
endif

endef

$(foreach h,$(hosts),$(eval $(call add_toolchain,$(TARGET),$h)))
$(eval $(call add_toolchain,$(HOST),$(BUILD)))

$(TARGET)-toolchain-$(HOST).tar.gz : .stamp.binutils-$(TARGET)-$(HOST) \
                                     .stamp.gcc-$(TARGET)-$(HOST) \
                                     .stamp.newlib-$(TARGET)-$(HOST)
	@echo "Creating $@"
	@rm -f $@
	@rm -rf $(TARGET)-toolchain-$(HOST)
	@export PATH=$(CURDIR)/sysroots/$(BUILD)/bin:$$PATH && \
	for pkg in binutils gcc newlib; do \
		make -C $$pkg-$(TARGET)-$(HOST) install-strip \
			DESTDIR=$(CURDIR)/$(TARGET)-toolchain-$(HOST) \
			&> $$pkg-install-$(TARGET)-$(HOST).log; \
	done
	@cd $(TARGET)-toolchain-$(HOST)/$(CURDIR)/sysroots/$(HOST) && \
	tar -czf $(CURDIR)/$@ *
	@rm -rf $(TARGET)-toolchain-$(HOST)

clean :
	rm -f .stamp.*
	rm -rf binutils-* gcc-* newlib-* mingw-w64-*
	rm -rf sysroots
	rm -f *-toolchain-*.tar.gz
