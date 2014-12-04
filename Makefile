

all:
	true

INSTALL_DIRS = tcl

install:
	find $(INSTALL_DIRS) -type d -exec install -d -m755 $(DESTDIR)/usr/share/fpgamake/{} \; -print
	find $(INSTALL_DIRS) -type f -exec install -m644 {} $(DESTDIR)/usr/share/fpgamake/{} \; -print
	install -m755 fpgamake $(DESTDIR)/usr/share/fpgamake/fpgamake

VERSION=14.10.1

spkg:
	sed -i s/trusty/precise/g debian/changelog
	git buildpackage --git-debian-tag="v%s" --git-upstream-branch=master --git-debian-branch=ubuntu -S -tc
	sed -i s/precise/trusty/g debian/changelog
	git buildpackage --git-debian-tag="v%s" --git-upstream-branch=master --git-debian-branch=ubuntu --git-ignore-new -S -tc
