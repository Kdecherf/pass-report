PREFIX ?= /usr
DESTDIR ?=
LIBDIR ?= $(PREFIX)/lib
SYSTEM_EXTENSION_DIR ?= $(LIBDIR)/password-store/extensions

install:
	@install -v -d "$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/"
	@install -v -m 0755 report.bash "$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/report.bash"

uninstall:
	@rm -vf "$(DESTDIR)$(SYSTEM_EXTENSION_DIR)/report.bash"

.PHONY: install uninstall
