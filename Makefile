ARCH            = x64
# You can alter the subsystem according to your EFI binary target:
# 10 = EFI application
# 11 = EFI boot service driver
# 12 = EFI runtime driver
SUBSYSTEM       = 10

SOURCES_common = disk.c graphics.c measure.c pe.c secure-boot.c util.c fundamental/string-util-fundamental.c
SOURCES_linux_efi = linux.c splash.c stub.c $(SOURCES_common)

ifeq ($(shell uname -m),x86_64)
  ARCH        = x64
else ifeq ($(shell uname -m),arm)
  ARCH        = arm
else ifeq ($(shell uname -m),aarch64)
  ARCH        = aa64
else
  ARCH        = ia32
endif

ifeq ($(ARCH),x64)
  GNUEFI_ARCH   = x86_64
  GCC_ARCH      = x86_64
  QEMU_ARCH     = x86_64
  CFLAGS        = -m64 -mno-red-zone -mno-sse -mno-mmx -DEFI_FUNCTION_WRAPPER -DGNU_EFI_USE_MS_ABI 
  LDFLAGS       = 
else ifeq ($(ARCH),ia32)
  GNUEFI_ARCH   = ia32
  GCC_ARCH      = i686
  QEMU_ARCH     = i386
  CFLAGS        = -m32 -mno-red-zone -mno-sse -mno-mmx
  LDFLAGS       = 
else ifeq ($(ARCH),arm)
  GNUEFI_ARCH   = arm
  GCC_ARCH      = arm
  QEMU_ARCH     = arm
  CFLAGS        = -marm -mfpu=none -fpic -fshort-wchar
  LDFLAGS       = -Wl,--no-wchar-size-warning -Wl,--defsym=EFI_SUBSYSTEM=$(SUBSYSTEM)
  CRT0_LIBS     = -lgnuefi
else ifeq ($(ARCH),aa64)
  GNUEFI_ARCH   = aarch64
  GCC_ARCH      = aarch64
  QEMU_ARCH     = aarch64
  FW_BASE       = QEMU_EFI
  EP_PREFIX     =
  CFLAGS        = -mfpu=none -fpic -fshort-wchar
  LDFLAGS       = -Wl,--no-wchar-size-warning -Wl,--defsym=EFI_SUBSYSTEM=$(SUBSYSTEM)
  CRT0_LIBS     = -lgnuefi
endif

GNUEFI_DIR      = $(CURDIR)/gnu-efi
GNUEFI_LIBS     = lib

# If the compiler produces an elf binary, we need to fiddle with a PE crt0
ifneq ($(CRT0_LIBS),)
  CRT0_DIR      = $(GNUEFI_DIR)/$(GNUEFI_ARCH)/gnuefi
  LDFLAGS      += -L$(CRT0_DIR) -T $(GNUEFI_DIR)/gnuefi/elf_$(GNUEFI_ARCH)_efi.lds $(CRT0_DIR)/crt0-efi-$(GNUEFI_ARCH).o
  GNUEFI_LIBS  += gnuefi
endif

CC = gcc
LD = ld
OC = objcopy

CFLAGS += -c                          \
	  -fno-stack-protector        \
	  -fpic                       \
	  -fshort-wchar               \
	  -DSD_BOOT \
	  -I$(GNUEFI_DIR)/inc -I$(GNUEFI_DIR)/inc/$(GNUEFI_ARCH) -I$(GNUEFI_DIR)/inc/protocol \
	  -Ifundamental \
	  -include version.h \
	  -mno-red-zone               \
	  -pedantic                   \
	  -nostdlib \
	  -std=gnu99                    \
	  -Wall                       \
	  -Wextra

LDFLAGS += $(GNUEFI_DIR)/$(GNUEFI_ARCH)/lib/libefi.a \
	   -Bshareable                          \
	   -Bsymbolic                           \
	   -nostdlib                            \
	   -z nocombreloc

OCFLAGS = -j .text    \
	  -j .sdata   \
	  -j .sbat    \
	  -j .data    \
	  -j .dynamic \
	  -j .dynsym  \
	  -j .rel*    \
	  --target=efi-app-$(GNUEFI_ARCH)


# disable built-in implicit rules
MAKEFLAGS += --no-builtin-rules
 
 
# default target
PHONY = all
all: $(GNUEFI_DIR)/$(GNUEFI_ARCH)/lib/libefi.a linux.efi

$(GNUEFI_DIR)/$(GNUEFI_ARCH)/lib/libefi.a:
	$(MAKE) -C$(GNUEFI_DIR) ARCH=$(GNUEFI_ARCH) $(GNUEFI_LIBS)
 
# object files
%.o: %.c
	${CC} ${CFLAGS} $< -o $@
 
linux.so: ${patsubst %.c,%.o,${SOURCES_linux_efi}} 
	${LD} $^ ${LDFLAGS} --output=$@

linux.efi: linux.so
	${OC} ${OCFLAGS} $< $@
 
 
PHONY += clean
clean:
	rm --force ${patsubst %.c,%.o,${SOURCES_linux_efi}} ${NAME}.so ${NAME}.efi
 
 
.PHONY: ${PHONY}

