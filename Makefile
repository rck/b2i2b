PREFIX ?= /usr/local
BINDIR  = $(DESTDIR)$(PREFIX)/bin

.PHONY: install uninstall check test

install:
	install -d $(BINDIR)
	install -m 0755 b2i2b $(BINDIR)/b2i2b
	ln -sf b2i2b $(BINDIR)/b2i
	ln -sf b2i2b $(BINDIR)/i2b

uninstall:
	rm -f $(BINDIR)/b2i2b $(BINDIR)/b2i $(BINDIR)/i2b

check:
	bash -n b2i2b
	@command -v shellcheck >/dev/null && shellcheck b2i2b || echo "shellcheck not installed, skipped"

test:
	sudo tests/loop-test.sh
