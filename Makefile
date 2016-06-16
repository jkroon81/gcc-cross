packages := binutils
binutils_version := 2.26
binutils_suffix := .tar.bz2
binutils_location := http://ftp.gnu.org/gnu/binutils/

all : build-packages

.PHONY : build-packages

define add_package
build-packages : .stamp.build-$1

$1-$($1_version) : sources/$1-$$($1_version)$$($1_suffix)
	tar -xf $$<

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
