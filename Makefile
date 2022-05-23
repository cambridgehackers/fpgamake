

all:
	true

INSTALL_DIRS = tcl

install:
	find $(INSTALL_DIRS) -type d -exec install -d -m755 $(DESTDIR)/usr/share/fpgamake/{} \; -print
	find $(INSTALL_DIRS) -type f -exec install -m644 {} $(DESTDIR)/usr/share/fpgamake/{} \; -print
	install -m755 fpgamake $(DESTDIR)/usr/share/fpgamake/fpgamake

VERSION=22.05.23

spkg:
	gbp buildpackage --git-ignore-new --git-debian-tag="v%s" --git-upstream-branch=master "--git-upstream-tag=v%(version)s" --git-debian-branch=ubuntu -S -tc -pgpg2 '--git-upstream-tag=v%(version)s'
	git checkout debian
	git clean -fdx
	sed -i s/trusty/xenial/g debian/changelog
	gbp buildpackage --git-ignore-new --git-debian-tag="v%s" --git-upstream-branch=master "--git-upstream-tag=v%(version)s" --git-debian-branch=ubuntu -S -tc -pgpg2 '--git-upstream-tag=v%(version)s' --git-ignore-new
	git checkout debian
	sed -i s/trusty/bionic/g debian/changelog
	gbp buildpackage --git-ignore-new --git-debian-tag="v%s" --git-upstream-branch=master "--git-upstream-tag=v%(version)s" --git-debian-branch=ubuntu -S -tc -pgpg2 '--git-upstream-tag=v%(version)s' --git-ignore-new
	git checkout debian
	sed -i s/trusty/jammy/g debian/changelog
	gbp buildpackage --git-ignore-new --git-debian-tag="v%s" --git-upstream-branch=master "--git-upstream-tag=v%(version)s" --git-debian-branch=ubuntu -S -tc -pgpg2 '--git-upstream-tag=v%(version)s' --git-ignore-new
	git checkout debian

upload:
	git push origin v$(VERSION)
	dput ppa:jamey-hicks/connectal ../fpgamake_$(VERSION)-*_source.changes
