GNUEFI_DIR = $(CURDIR)/gnu-efi

include Makefile.defaults

SOURCES_common = disk.c graphics.c measure.c pe.c secure-boot.c util.c fundamental/string-util-fundamental.c
SOURCES_linux_efi = linux.c splash.c stub.c $(SOURCES_common)

GIT_VERSION = $(shell git describe --tags || git rev-parse HEAD)

TARGET_NAME_linux_efi = linux$(EFI_ARCH)

CRTOBJS		= $(GNUEFI_DIR)/$(ARCH)/gnuefi/crt0-efi-$(ARCH).o
LDSCRIPT	= $(GNUEFI_DIR)/gnuefi/elf_$(ARCH)_efi.lds
ifneq (,$(findstring FreeBSD,$(OS)))
LDSCRIPT	= $(GNUEFI_DIR)/gnuefi/elf_$(ARCH)_fbsd_efi.lds
endif

#CFLAGS += -c                          \
#	  -fno-stack-protector        \
#	  -fpic                       \
#	  -fshort-wchar               \
#	  -DSD_BOOT \
#	  -Ifundamental \
#	  -include version.h \
#	  -mno-red-zone               \
#	  -pedantic                   \
#	  -nostdlib \
#	  -std=gnu99                    \
#	  -Wall                       \
#	  -Wextra

CFLAGS += -DENABLE_TPM -DSD_TPM_PCR=8 -std=gnu99
INCDIR += -DSD_BOOT -I$(CURDIR)/fundamental -include version.h

LDFLAGS += -shared -Bsymbolic -znocombreloc -L$(GNUEFI_DIR)/$(ARCH)/lib -L$(GNUEFI_DIR)/$(ARCH)/gnuefi $(CRTOBJS)

# disable built-in implicit rules
MAKEFLAGS += --no-builtin-rules

LOADLIBES += -lefi -lgnuefi
LOADLIBES += $(LIBGCC)
LOADLIBES += -T$(LDSCRIPT)

FORMAT := --target efi-app-$(ARCH)
 
# default target
PHONY = all
all: $(TARGET_NAME_linux_efi).efi.stub

$(GNUEFI_DIR)/$(ARCH)/lib/libefi.a:
	$(MAKE) -C$(GNUEFI_DIR) ARCH=$(ARCH) lib

$(GNUEFI_DIR)/$(ARCH)/gnuefi/libgnuefi.a:
	$(MAKE) -C$(GNUEFI_DIR) ARCH=$(ARCH) gnuefi

version.h:
	sed -e "s/@GIT_VERSION@/${GIT_VERSION}/g;s/@EFI_MACHINE_TYPE_NAME@/${ARCH}/g" version.h.in > version.h
	cat version.h
 
%.efi: %.so
	$(OBJCOPY) -j .text -j .sdata -j .sbat -j .data -j .dynamic -j .dynsym -j ".rel*" \
		   $(FORMAT) $*.so $@

%.efi.debug: %.so
	$(OBJCOPY) -j .debug_info -j .debug_abbrev -j .debug_aranges \
		-j .debug_line -j .debug_str -j .debug_ranges \
		-j .note.gnu.build-id \
		$(FORMAT) $*.so $@

#%.so: %.o
#	$(LD) $(LDFLAGS) $^ -o $@ $(LOADLIBES)

%.o: %.c version.h
	$(CC) $(INCDIR) $(CFLAGS) $(CPPFLAGS) -c $< -o $@

$(TARGET_NAME_linux_efi).so: ${patsubst %.c,%.o,${SOURCES_linux_efi}} $(GNUEFI_DIR)/$(ARCH)/lib/libefi.a $(GNUEFI_DIR)/$(ARCH)/gnuefi/libgnuefi.a
	$(LD) $(LDFLAGS) $^ -o $@ $(LOADLIBES)

$(TARGET_NAME_linux_efi).efi.stub: $(TARGET_NAME_linux_efi).efi
	cp $(TARGET_NAME_linux_efi).efi $(TARGET_NAME_linux_efi).efi.stub
 
PHONY += clean
clean:
	rm --force ${patsubst %.c,%.o,${SOURCES_linux_efi}} ${TARGET_NAME_linux_efi}.so ${TARGET_NAME_linux_efi}.efi
 
.PHONY: ${PHONY}

