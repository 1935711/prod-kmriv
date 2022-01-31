include lib/make-pal/pal.mak
DIR_BUILD:=build
DIR_LIB:=lib
DIR_SOURCE:=src

MAIN_NAME:=kmriv
MAIN_EXT:=bin
MAIN_SRC:= $(DIR_SOURCE)/kmriv.asm
MAIN_ASM_FLAGS:=

.PHONY: all main clean run

all: main

main: $(DIR_BUILD) $(DIR_BUILD)/$(MAIN_NAME).$(MAIN_EXT)
$(DIR_BUILD)/$(MAIN_NAME).$(MAIN_EXT): $(MAIN_SRC)
	fasm $(MAIN_SRC) $(@) -s $(DIR_BUILD)/$(MAIN_NAME).fas $(MAIN_ASM_FLAGS)
	-listing $(DIR_BUILD)/$(MAIN_NAME).fas $(DIR_BUILD)/$(MAIN_NAME).lst
	-symbols $(DIR_BUILD)/$(MAIN_NAME).fas $(DIR_BUILD)/$(MAIN_NAME).sym

$(DIR_BUILD):
	$(call pal_mkdir,$(@))
clean:
	$(call pal_rmdir,$(DIR_BUILD))
qemu-run: main
	@qemu-system-x86_64 -display sdl -drive file=$(DIR_BUILD)/$(MAIN_NAME).$(MAIN_EXT),index=0,media=disk,format=raw
qemu-dbg: main
	@qemu-system-x86_64 -display sdl -S -s -drive file=$(DIR_BUILD)/$(MAIN_NAME).$(MAIN_EXT),index=0,media=disk,format=raw
bochs-run: main
	@bochs -n -q 'boot:a' 'floppya: 1_44=$(DIR_BUILD)/$(MAIN_NAME).$(MAIN_EXT), status=inserted'
bochs-dbg: main
	@bochs -n -q 'display_library:x, options="gui_debug"' 'boot:a' 'floppya: 1_44=$(DIR_BUILD)/$(MAIN_NAME).$(MAIN_EXT), status=inserted'
