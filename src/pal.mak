ifeq ($(OS),Windows_NT)
define pal_mkdir
	if not exist "$(subst /,\,$(1))" mkdir "$(subst /,\,$(1))"
endef
define pal_rmdir
	if exist "$(subst /,\,$(1))" rmdir /Q /S "$(subst /,\,$(1))"
endef
else
define pal_mkdir
	mkdir -p $(1)
endef
define pal_rmdir
	rm -rf $(1)
endef
endif
