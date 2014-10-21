

all:
	true

INSTALL_DIRS = $(shell ls | grep -v debian)

install:
	find $(INSTALL_DIRS) -type d -exec install -d -m755 $(DESTDIR)/usr/share/fpgamake/{} \; -print
	find $(INSTALL_DIRS) -type f -exec install -m644 {} $(DESTDIR)/usr/share/fpgamake/{} \; -print
	install -m755 fpgamake $(DESTDIR)/usr/share/fpgamake/fpgamake

VERSION=14.10.1

dpkg:
	git archive --format=tar -o dpkg.tar --prefix=fpgamake-$(VERSION)/ HEAD
	tar -xf dpkg.tar
	rm -f fpgamake_*
	(cd fpgamake-$(VERSION); pwd; dh_make --createorig --email jamey.hicks@gmail.com --multi -c bsd; dpkg-buildpackage -S)
