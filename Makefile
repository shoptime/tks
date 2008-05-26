all: build

clean:
	fakeroot make -f debian/rules clean

build:
	dpkg-buildpackage -rfakeroot -us -uc -b -tc

debug:
	dpkg-buildpackage -rfakeroot -us -uc -b

.PHONY: build
