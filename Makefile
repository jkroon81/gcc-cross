packages := binutils gcc gmp isl mingw-w64 mpc mpfr newlib

define def_pkg
$1_version  := $2
$1_suffix   := $3
$1_location := $4
endef

gnu_mirror := http://ftp.gnu.org/gnu
gcc_mirror := ftp://gcc.gnu.org/pub

$(eval $(call def_pkg,binutils,2.26,.tar.bz2,$(gnu_mirror)/binutils/))
$(eval $(call def_pkg,gcc,6.1.0,.tar.bz2,$(gnu_mirror)/gcc/gcc-6.1.0/))
$(eval $(call def_pkg,gmp,6.1.0,.tar.bz2,$(gnu_mirror)/gmp/))
$(eval $(call def_pkg,isl,0.16.1,.tar.bz2,$(gcc_mirror)/gcc/infrastructure/))
$(eval $(call def_pkg,mingw-w64,v4.0.6,.tar.bz2,http://sourceforge.mirrorservice.org/m/mi/mingw-w64/mingw-w64/mingw-w64-release/))
$(eval $(call def_pkg,mpc,1.0.3,.tar.gz,$(gnu_mirror)/mpc/))
$(eval $(call def_pkg,mpfr,3.1.4,.tar.bz2,$(gnu_mirror)/mpfr/))
$(eval $(call def_pkg,newlib,2.4.0,.tar.gz,$(gcc_mirror)/newlib/))

build := x86_64-redhat-linux
mingw := x86_64-w64-mingw32

njobs := $(shell expr 2 \* `cat /proc/cpuinfo | grep processor | wc -l`)

HOST ?= $(mingw)
TARGET ?= h8300-elf

prefix  := /usr
destdir := $(CURDIR)/sysroot
PATH    := $(destdir)$(prefix)/bin:$(PATH)

cf_gcc_$(TARGET)_$(HOST)  := --enable-languages=c
cf_gcc_$(TARGET)_$(build) := --enable-languages=c
cf_gcc_$(HOST)_$(build)   := --enable-languages=c,c++

crt_$(mingw) := mingw-w64-crt
cf_binutils_$(mingw)_$(build) := --disable-multilib
cf_gcc_$(mingw)_$(build) += --disable-multilib

crt_arm-none-eabi := newlib
cf_binutils_arm-none-eabi_$(build) := --disable-werror
cf_binutils_arm-none-eabi_$(HOST)  := --disable-werror
cf_gcc_arm-none-eabi_$(build) += --with-newlib
cf_gcc_arm-none-eabi_$(HOST)  += --with-newlib

crt_h8300-elf := newlib
cf_gcc_h8300-elf_$(build) += --with-newlib
cf_gcc_h8300-elf_$(HOST)  += --with-newlib
cflags_for_target_h8300-elf   := -Os -fomit-frame-pointer
cxxflags_for_target_h8300-elf := -Os -fomit-frame-pointer

ifeq ($(crt_$(TARGET)),)
$(error No CRT defined for target $(TARGET))
endif

define cf_binutils
--build=$(build) \
--host=$2 \
--target=$1 \
--prefix=$(prefix) \
--with-sysroot=$(prefix) \
--disable-dependency-tracking \
--disable-nls \
$(cf_binutils_$1_$2)
endef

define cf_gcc
--build=$(build) \
--host=$2 \
--target=$1 \
--prefix=$(prefix) \
--with-sysroot=$(prefix) \
--with-build-sysroot=$(destdir)$(prefix) \
--disable-decimal-float \
--disable-fixed-point \
--disable-libquadmath \
--disable-libssp \
--disable-lto \
--disable-nls \
$(call cf_gcc_$1_$2,$1,$2) \
$(if $(cflags_for_target_$1),CFLAGS_FOR_TARGET='$(cflags_for_target_$1)',) \
$(if $(cxxflags_for_target_$1),CXXFLAGS_FOR_TARGET='$(cxxflags_for_target_$1)',)
endef

define cf_newlib
--build=$(build) \
--host=$(build) \
--target=$1 \
--prefix=$(prefix) \
--disable-dependency-tracking \
--disable-newlib-supplied-syscalls \
--disable-nls \
$(cf_newlib_$1) \
$(if $(cflags_for_target_$1),CFLAGS_FOR_TARGET='$(cflags_for_target_$1)',) \
$(if $(cxxflags_for_target_$1),CXXFLAGS_FOR_TARGET='$(cxxflags_for_target_$1)',)
endef

define cf_mingw
--build=$(build) \
--host=$1 \
--prefix=$(prefix)/$(mingw)
endef
# passing --enable-sdk=no will break the CRT build
cf_mingw-w64-headers = $(cf_mingw)
mingw-w64-headers_version := $(mingw-w64_version)
cf_mingw-w64-crt = $(cf_mingw)
mingw-w64-crt_version := $(mingw-w64_version)

all : $(TARGET)-toolchain-$(HOST).tar.gz

define add_package
.stamp.$1-unpack : sources/$1-$$($1_version)$$($1_suffix)
	$$(info Unpacking $1)
	@tar -xf $$<
	@touch $$@

sources/$1-$$($1_version)$$($1_suffix) :
	$$(info Downloading $1)
	@wget --quiet -P sources $$($1_location)$$(notdir $$@)
endef

$(foreach p,$(packages),$(eval $(call add_package,$p)))

.stamp.gcc-with-libs-unpack : .stamp.gcc-unpack \
                              .stamp.gmp-unpack \
                              .stamp.isl-unpack \
                              .stamp.mpc-unpack \
                              .stamp.mpfr-unpack
	$(info Creating symlinks in gcc)
	@ln -sf ../gmp-$(gmp_version) gcc-$(gcc_version)/gmp
	@ln -sf ../isl-$(isl_version) gcc-$(gcc_version)/isl
	@ln -sf ../mpc-$(mpc_version) gcc-$(gcc_version)/mpc
	@ln -sf ../mpfr-$(mpfr_version) gcc-$(gcc_version)/mpfr
	@touch $@

define prep_build
$(info Building $1($2) for $3) \
mkdir -p $1-$2-$3 && \
cd $1-$2-$3 && \
if [ ! -e config.status ]; then \
	../$1-$($1_version)/configure $(call cf_$1,$2,$3); \
fi
endef

.stamp.newlib-$(TARGET) : .stamp.newlib-unpack .stamp.gcc-bootstrap-$(TARGET)
	@($(call prep_build,newlib,$(TARGET),all) && \
	make -j $(njobs) && \
	make install DESTDIR=$(destdir) \
	) >> $(CURDIR)/newlib-$(TARGET).log 2>&1
	@touch $@

.stamp.mingw-w64-headers : .stamp.mingw-w64-unpack \
                           .stamp.binutils-$(mingw)-$(build)
	@ln -sf mingw-w64-$(mingw-w64_version)/mingw-w64-headers \
	        mingw-w64-headers-$(mingw-w64_version)
	@($(call prep_build,mingw-w64-headers,$(mingw),all) && \
	make install DESTDIR=$(destdir) && \
	ln -s $(mingw) $(destdir)$(prefix)/mingw \
	) >> $(CURDIR)/mingw-w64-headers.log 2>&1
	@touch $@

.stamp.mingw-w64-crt-$(mingw) : .stamp.gcc-bootstrap-$(mingw)
	@ln -sf mingw-w64-$(mingw-w64_version)/mingw-w64-crt \
	        mingw-w64-crt-$(mingw-w64_version)
	@($(call prep_build,mingw-w64-crt,$(mingw),all) && \
	make -j $(njobs) && \
	make install-strip DESTDIR=$(destdir) \
	) >> $(CURDIR)/mingw-w64-crt-$(mingw).log 2>&1
	@touch $@

define add_toolchain
.stamp.binutils-$1-$2 : .stamp.binutils-unpack
	@($$(call prep_build,binutils,$1,$2) && \
	make -j $(njobs) && \
	if [ "$2" = "$(build)" ]; then \
		make install-strip DESTDIR=$(destdir); \
	fi ) >> $(CURDIR)/binutils-$1-$2.log 2>&1
	@touch $$@

ifneq ($2-$(build),$(build)-$(build))
.stamp.binutils-$1-$2 : .stamp.gcc-$2-$(build)
endif

ifeq ($2,$(build))
.stamp.gcc-bootstrap-$1 : .stamp.gcc-with-libs-unpack .stamp.binutils-$1-$2
	@($$(call prep_build,gcc,$1,$2) && \
	make all-gcc -j $(njobs) && \
	make install-gcc DESTDIR=$(destdir) \
	) >> $(CURDIR)/gcc-$1-$2.log 2>&1
	@touch $$@

ifeq ($1,$(mingw))
.stamp.gcc-bootstrap-$1 : .stamp.mingw-w64-headers
endif
endif

ifeq ($2,$(build))
.stamp.gcc-$1-$2 :
	$$(info Continuing gcc($1) for $2)
	@(cd gcc-$1-$2 && \
	make -j $(njobs) && \
	if [ "$1-$2" != "$(TARGET)-$(HOST)" ]; then \
		make install-strip DESTDIR=$(destdir); \
	fi ) >> gcc-$1-$2.log 2>&1
	@touch $$@
else
.stamp.gcc-$1-$2 : .stamp.gcc-with-libs-unpack
	@($$(call prep_build,gcc,$1,$2) && \
	make -j $(njobs)) >> $(CURDIR)/gcc-$1-$2.log 2>&1
	@touch $$@
endif

.stamp.gcc-$1-$2 : .stamp.$(crt_$1)-$1

endef

$(eval $(call add_toolchain,$(TARGET),$(HOST)))
ifneq ($(HOST),$(build))
  $(eval $(call add_toolchain,$(HOST),$(build)))
  ifneq ($(TARGET),$(HOST))
    $(eval $(call add_toolchain,$(TARGET),$(build)))
  endif
endif

$(TARGET)-toolchain-$(HOST).tar.gz : .stamp.binutils-$(TARGET)-$(HOST) \
                                     .stamp.gcc-$(TARGET)-$(HOST) \
                                     .stamp.$(crt_$(TARGET))-$(TARGET)
	$(info Creating $@)
	@rm -f $@
	@rm -rf _install-$(TARGET)-$(HOST)
	@for p in binutils gcc; do \
		make -C $$p-$(TARGET)-$(HOST) install-strip \
			DESTDIR=$(CURDIR)/_install-$(TARGET)-$(HOST) \
			>> $$p-install-$(TARGET)-$(HOST).log 2>&1; \
	done && \
	make -C $(crt_$(TARGET))-$(TARGET)-all install \
		DESTDIR=$(CURDIR)/_install-$(TARGET)-$(HOST) \
		>> $(crt_$(TARGET))-install-$(TARGET)-$(HOST).log 2>&1
	@cd _install-$(TARGET)-$(HOST)$(prefix) && \
	find -type d -empty -delete && \
	tar -czf $(CURDIR)/$@ *
	@rm -rf _install-$(TARGET)-$(HOST)

.PHONY : clean
clean :
	for p in $(packages); do \
		rm -rf $$p-*; \
	done
	rm -f .stamp.*
	rm -rf sysroot
	rm -f *-toolchain-*.tar.gz
