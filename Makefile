

all:
	true

INSTALL_DIRS = tcl

install:
	find $(INSTALL_DIRS) -type d -exec install -d -m755 $(DESTDIR)/usr/share/fpgamake/{} \; -print
	find $(INSTALL_DIRS) -type f -exec install -m644 {} $(DESTDIR)/usr/share/fpgamake/{} \; -print

VERSION=14.10.1

spkg:
	sed s/trusty/precise/g debian/changelog
	git buildpackage --git-debian-tag="v%s" --git-upstream-branch=master --git-debian-branch=ubuntu/precise -S -tc
	sed s/precise/trusty/g debian/changelog
	git buildpackage --git-debian-tag="v%s" --git-upstream-branch=master --git-debian-branch=ubuntu/precise -S -tc
