

all:
	true

INSTALL_DIRS = tcl

install:
	find $(INSTALL_DIRS) -type d -exec install -d -m755 $(DESTDIR)/usr/share/fpgamake/{} \; -print
	find $(INSTALL_DIRS) -type f -exec install -m644 {} $(DESTDIR)/usr/share/fpgamake/{} \; -print
	install -m755 fpgamake $(DESTDIR)/usr/share/fpgamake/fpgamake

VERSION=15.09.1

spkg:
	git buildpackage --git-debian-tag="v%s" --git-upstream-branch=master "--git-upstream-tag=v%(version)s" --git-debian-branch=ubuntu -S -tc '--git-upstream-tag=v%(version)s'
	sed -i s/trusty/precise/g debian/changelog
	git clean -fdx
	git buildpackage --git-debian-tag="v%s" --git-upstream-branch=master "--git-upstream-tag=v%(version)s" --git-debian-branch=ubuntu -S -tc '--git-upstream-tag=v%(version)s' --git-ignore-new
	git checkout debian
	git clean -fdx
	sed -i s/trusty/utopic/g debian/changelog
	git buildpackage --git-debian-tag="v%s" --git-upstream-branch=master "--git-upstream-tag=v%(version)s" --git-debian-branch=ubuntu -S -tc '--git-upstream-tag=v%(version)s' --git-ignore-new
	git checkout debian
	sed -i s/trusty/vivid/g debian/changelog
	git buildpackage --git-debian-tag="v%s" --git-upstream-branch=master "--git-upstream-tag=v%(version)s" --git-debian-branch=ubuntu -S -tc '--git-upstream-tag=v%(version)s' --git-ignore-new
	git checkout debian

upload:
	git push origin v$(VERSION)
	dput ppa:jamey-hicks/connectal ../fpgamake_$(VERSION)-*_source.changes
	(cd  ../obs/home:jameyhicks:connectaldeb/fpgamake/; osc rm * || true)
	cp -v ../fpgamake_$(VERSION)*trusty*.diff.gz ../fpgamake_$(VERSION)*trusty*.dsc ../fpgamake_$(VERSION)*.orig.tar.gz ../obs/home:jameyhicks:connectaldeb/fpgamake/
	(cd ../obs/home:jameyhicks:connectaldeb/fpgamake/; osc add *; osc commit -m $(VERSION) )
	(cd ../obs/home:jameyhicks:connectal/fpgamake; sed -i "s/>v.....</>v$(VERSION)</" _service; osc commit -m "v$(VERSION)" )
