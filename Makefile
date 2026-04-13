.PHONY: install uninstall test

PREFIX   = /usr
DESTDIR  =
pkgname  = fkzys-tools

BINDIR     = $(PREFIX)/bin
LICENSEDIR = $(PREFIX)/share/licenses/$(pkgname)

install:
	install -Dm755 bin/bash-lint     $(DESTDIR)$(BINDIR)/bash-lint
	install -Dm755 bin/bash-coverage $(DESTDIR)$(BINDIR)/bash-coverage
	install -Dm755 bin/fkzys-audit   $(DESTDIR)$(BINDIR)/fkzys-audit
	install -Dm644 LICENSE           $(DESTDIR)$(LICENSEDIR)/LICENSE

uninstall:
	rm -f  $(DESTDIR)$(BINDIR)/bash-lint
	rm -f  $(DESTDIR)$(BINDIR)/bash-coverage
	rm -f  $(DESTDIR)$(BINDIR)/fkzys-audit
	rm -rf $(DESTDIR)$(LICENSEDIR)/

test:
	fail=0; bash tests/test_bash_lint.sh || fail=1; bash tests/test_fkzys_audit.sh || fail=1; bash tests/test_bash_coverage.sh || fail=1; exit $$fail
