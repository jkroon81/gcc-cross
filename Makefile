packages := binutils gcc gmp isl mingw-w64 mpc mpfr newlib
binutils_version := 2.26
binutils_suffix := .tar.bz2
binutils_location := http://ftp.gnu.org/gnu/binutils/
gcc_version := 6.1.0
gcc_suffix := .tar.bz2
gcc_location := ftp://ftp.fu-berlin.de/unix/languages/gcc/releases/gcc-6.1.0/
gmp_version := 6.1.0
gmp_suffix := .tar.bz2
gmp_location := ftp://gcc.gnu.org/pub/gcc/infrastructure/
isl_version := 0.16.1
isl_suffix := .tar.bz2
isl_location := ftp://gcc.gnu.org/pub/gcc/infrastructure/
mingw-w64_version := v4.0.6
mingw-w64_suffix := .tar.bz2
mingw-w64_location := http://sourceforge.mirrorservice.org/m/mi/mingw-w64/mingw-w64/mingw-w64-release/
mpc_version := 1.0.3
mpc_suffix := .tar.gz
mpc_location := ftp://gcc.gnu.org/pub/gcc/infrastructure/
mpfr_version := 3.1.4
mpfr_suffix := .tar.bz2
mpfr_location := ftp://gcc.gnu.org/pub/gcc/infrastructure/
newlib_version := 2.4.0
newlib_suffix := .tar.gz
newlib_location := ftp://sourceware.org/pub/newlib/

build := x86_64-redhat-linux
mingw := x86_64-w64-mingw32

hosts := $(build) $(mingw)
njobs := $(shell expr 2 \* `cat /proc/cpuinfo | grep processor | wc -l`)

HOST ?= $(mingw)
TARGET ?= h8300-elf

crt_$(TARGET) := newlib
crt_$(mingw)  := mingw-w64-crt

prefix  := /usr
destdir := $(CURDIR)/sysroot

define cf_binutils
--build=$(build) \
--host=$2 \
--target=$1 \
--prefix=$(prefix) \
--with-sysroot=$(prefix) \
--disable-dependency-tracking \
--disable-nls
endef

define cf_gcc_$(TARGET)
--enable-languages=c \
--with-newlib \
CFLAGS_FOR_TARGET='-Os -fomit-frame-pointer' \
CXXFLAGS_FOR_TARGET='-Os -fomit-frame-pointer'
endef

define cf_gcc_$(mingw)
--enable-languages=c,c++
endef

define cf_gcc
--build=$(build) \
--host=$2 \
--target=$1 \
--prefix=$(prefix) \
--with-sysroot=$(prefix) \
--with-build-sysroot=$(destdir)$(prefix) \
--disable-decimal-float \
--disable-libquadmath \
--disable-libssp \
--disable-nls \
$(call cf_gcc_$1,$1,$2)
endef

define cf_newlib
--build=$(build) \
--host=$(build) \
--target=$1 \
--prefix=$(prefix) \
--disable-dependency-tracking \
--disable-newlib-supplied-syscalls \
--disable-nls \
CFLAGS_FOR_TARGET='-Os -fomit-frame-pointer' \
CXXFLAGS_FOR_TARGET='-Os -fomit-frame-pointer'
endef

define cf_mingw
--build=$(build) \
--host=$1 \
--prefix=$(prefix)/$(mingw)
endef

all : $(TARGET)-toolchain-$(HOST).tar.gz

define add_package
.stamp.$1-unpack : sources/$1-$$($1_version)$$($1_suffix)
	@echo "Unpacking $1"
	@rm -rf $1-$$($1_version)
	@tar -xf $$<
	@touch $$@

sources/$1-$$($1_version)$$($1_suffix) :
	@echo "Downloading $1"
	@wget --quiet -P sources $$($1_location)$$(notdir $$@)
endef

$(foreach p,$(packages),$(eval $(call add_package,$p)))

.stamp.gcc-with-libs-unpack : .stamp.gcc-unpack \
                              .stamp.gmp-unpack \
                              .stamp.isl-unpack \
                              .stamp.mpc-unpack \
                              .stamp.mpfr-unpack
	@echo "Creating symlinks in gcc"
	@ln -sf ../gmp-$(gmp_version) gcc-$(gcc_version)/gmp
	@ln -sf ../isl-$(isl_version) gcc-$(gcc_version)/isl
	@ln -sf ../mpc-$(mpc_version) gcc-$(gcc_version)/mpc
	@ln -sf ../mpfr-$(mpfr_version) gcc-$(gcc_version)/mpfr
	@touch $@

define prep_build
@echo "Building $1($2) for $3" && \
rm -rf $1-$2-$3 && \
mkdir $1-$2-$3 && \
cd $1-$2-$3 && \
export PATH=$(destdir)$(prefix)/bin:$$PATH
endef

.stamp.newlib-$(TARGET) : .stamp.newlib-unpack .stamp.gcc-bootstrap-$(TARGET)
	$(call prep_build,newlib,$(TARGET),all) && \
	( ../newlib-$(newlib_version)/configure \
		$(call cf_newlib,$(TARGET),all) && \
	make -j $(njobs) && \
	make install-strip DESTDIR=$(destdir) ) \
		&> $(CURDIR)/newlib-$(TARGET).log
	@touch $@

.stamp.mingw-w64-headers : .stamp.mingw-w64-unpack \
                           .stamp.binutils-$(mingw)-$(build)
	$(call prep_build,mingw-w64-headers,$(mingw),all) && \
	( ../mingw-w64-$(mingw-w64_version)/mingw-w64-headers/configure \
		$(call cf_mingw,$(mingw),all) && \
	make install DESTDIR=$(destdir) && \
	ln -s $(mingw) $(destdir)$(prefix)/mingw ) \
		&> $(CURDIR)/mingw-w64-headers.log
	@touch $@

.stamp.mingw-w64-crt-$(mingw) : .stamp.gcc-bootstrap-$(mingw)
	$(call prep_build,mingw-w64-crt,$(mingw),all) && \
	( ../mingw-w64-$(mingw-w64_version)/mingw-w64-crt/configure \
		$(call cf_mingw,$(mingw),all) && \
	make -j $(njobs) && \
	make install-strip DESTDIR=$(destdir) ) \
		&> $(CURDIR)/mingw-w64-crt-$(mingw).log
	@touch $@

define add_toolchain
.stamp.binutils-$1-$2 : .stamp.binutils-unpack
	$$(call prep_build,binutils,$1,$2) && \
	( ../binutils-$$(binutils_version)/configure \
		$$(call cf_binutils,$1,$2) && \
	make -j $(njobs) && \
	if [ "$2" = "$(build)" ]; then \
		make install-strip DESTDIR=$(destdir); \
	fi ) &> $(CURDIR)/binutils-$1-$2.log
	@touch $$@

ifneq ($2-$(build),$(build)-$(build))
.stamp.binutils-$1-$2 : .stamp.gcc-$2-$(build)
endif

ifeq ($2,$(build))
.stamp.gcc-bootstrap-$1 : .stamp.gcc-with-libs-unpack .stamp.binutils-$1-$2
	$$(call prep_build,gcc,$1,$2) && \
	( ../gcc-$$(gcc_version)/configure \
		$$(call cf_gcc,$1,$2) && \
	make all-gcc -j $(njobs) && \
	make install-gcc DESTDIR=$(destdir) ) \
		&> $(CURDIR)/gcc-$1-$2.log
	@touch $$@

ifeq ($1,$(mingw))
.stamp.gcc-bootstrap-$1 : .stamp.mingw-w64-headers
endif
endif

ifeq ($2,$(build))
.stamp.gcc-$1-$2 :
	@echo "Continuing gcc($1) for $2"
	@(cd gcc-$1-$2 && \
	export PATH=$(destdir)$(prefix)/bin:$$$$PATH && \
	make -j $(njobs) && \
	if [ "$1-$2" != "$(TARGET)-$(HOST)" ]; then \
		make install-strip DESTDIR=$(destdir); \
	fi ) >> gcc-$1-$2.log 2>&1
	@touch $$@
else
.stamp.gcc-$1-$2 : .stamp.gcc-with-libs-unpack
	$$(call prep_build,gcc,$1,$2) && \
	( ../gcc-$$(gcc_version)/configure \
		$$(call cf_gcc,$1,$2) && \
	make -j $(njobs) ) &> $(CURDIR)/gcc-$1-$2.log
	@touch $$@
endif

.stamp.gcc-$1-$2 : .stamp.$(crt_$1)-$1

endef

$(foreach h,$(hosts),$(eval $(call add_toolchain,$(TARGET),$h)))
ifneq ($(TARGET),$(HOST))
$(eval $(call add_toolchain,$(HOST),$(build)))
endif

$(TARGET)-toolchain-$(HOST).tar.gz : .stamp.binutils-$(TARGET)-$(HOST) \
                                     .stamp.gcc-$(TARGET)-$(HOST) \
                                     .stamp.$(crt_$(TARGET))-$(TARGET)
	@echo "Creating $@"
	@rm -f $@
	@rm -rf _install-$(TARGET)-$(HOST)
	@export PATH=$(destdir)$(prefix)/bin:$$PATH && \
	for p in binutils gcc; do \
		make -C $$p-$(TARGET)-$(HOST) install-strip \
			DESTDIR=$(CURDIR)/_install-$(TARGET)-$(HOST) \
			&> $$p-install-$(TARGET)-$(HOST).log; \
	done && \
	make -C $(crt_$(TARGET))-$(TARGET)-all install-strip \
		DESTDIR=$(CURDIR)/_install-$(TARGET)-$(HOST) \
		>> $(crt_$(TARGET))-install-$(TARGET)-$(HOST).log 2>&1
	@cd _install-$(TARGET)-$(HOST)$(prefix) && \
	tar -czf $(CURDIR)/$@ *
	@rm -rf _install-$(TARGET)-$(HOST)

clean :
	for p in $(packages); do \
		rm -rf $$p-*; \
	done
	rm -f .stamp.*
	rm -rf sysroot
	rm -f *-toolchain-*.tar.gz
