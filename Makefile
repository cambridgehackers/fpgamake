

all:
	true

INSTALL_DIRS = tcl

install:
	find $(INSTALL_DIRS) -type d -exec install -d -m755 $(DESTDIR)/usr/share/fpgamake/{} \; -print
	find $(INSTALL_DIRS) -type f -exec install -m644 {} $(DESTDIR)/usr/share/fpgamake/{} \; -print
	install -m755 fpgamake $(DESTDIR)/usr/share/fpgamake/fpgamake

VERSION=16.02.1

dpkg:
	git buildpackage --git-debian-tag="v%s" --git-upstream-branch=master --git-debian-branch=ubuntu/precise -S -tc
