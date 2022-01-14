include lib/make-pal/pal.mak
DIR_BUILD:=build
DIR_LIB:=lib
DIR_SOURCE:=src
ASM:=fasm

MAIN_NAME:=kmriv
MAIN_SRC:= $(DIR_SOURCE)/kmriv.asm
MAIN_ASM_FLAGS:=

.PHONY: all main clean run

all: main

main: $(DIR_BUILD) $(DIR_BUILD)/$(MAIN_NAME).img
$(DIR_BUILD)/$(MAIN_NAME).img: $(MAIN_SRC)
	$(ASM) $(MAIN_ASM_FLAGS) $(MAIN_SRC) $@

$(DIR_BUILD):
	$(call pal_mkdir,$(@))
clean:
	$(call pal_rmdir,$(DIR_BUILD))
run: main
	@qemu-system-x86_64 -s -drive file=$(DIR_BUILD)/$(MAIN_NAME).img,index=0,media=disk,format=raw
