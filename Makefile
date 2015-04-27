

all:
	true

INSTALL_DIRS = tcl

install:
	find $(INSTALL_DIRS) -type d -exec install -d -m755 $(DESTDIR)/usr/share/fpgamake/{} \; -print
	find $(INSTALL_DIRS) -type f -exec install -m644 {} $(DESTDIR)/usr/share/fpgamake/{} \; -print
	install -m755 fpgamake $(DESTDIR)/usr/share/fpgamake/fpgamake

VERSION=15.04.2

spkg:
	git buildpackage --git-debian-tag="v%s" --git-upstream-branch=master "--git-upstream-tag=v%(version)s" --git-debian-branch=ubuntu -S -tc '--git-upstream-tag=v%(version)s'
	sed -i s/trusty/precise/g debian/changelog
	git clean -fdx
	git buildpackage --git-debian-tag="v%s" --git-upstream-branch=master "--git-upstream-tag=v%(version)s" --git-debian-branch=ubuntu -S -tc '--git-upstream-tag=v%(version)s'
	git checkout debian
