include pal.mak
DIR_BUILD:=build
MAIN_NAME:=kmriv
MAIN_EXT:=bin
MAIN_SRC:= kmriv.asm
MAIN_ASM_FLAGS:=
QEMU_ARG:=-drive file=$(DIR_BUILD)/$(MAIN_NAME).$(MAIN_EXT),index=0,media=disk,format=raw
BOCHS_ARG:=-n -q 'boot:a' 'floppya: 1_44=$(DIR_BUILD)/$(MAIN_NAME).$(MAIN_EXT), status=inserted'
ifeq ($(OS),Windows_NT)
QEMU_ARG+=-display gtk,gl=off
else
QEMU_ARG+=-display x
endif

.PHONY: all main clean qemu-run qemu-dbg bochs-run bochs-dbg

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
	@qemu-system-x86_64 $(QEMU_ARG)
qemu-dbg: main
	@qemu-system-x86_64 -S -s $(QEMU_ARG)
bochs-run: main
	@bochs $(BOCHS_ARG)
bochs-dbg: main
ifeq ($(OS),Windows_NT)
	@bochs $(BOCHS_ARG) 'display_library:win32, options="gui_debug"'
else
	@bochs $(BOCHS_ARG) 'display_library:x, options="gui_debug"'
endif
