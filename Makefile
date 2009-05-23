all: build

clean:
	fakeroot make -f debian/rules clean

build:
	dpkg-buildpackage -rfakeroot -us -uc -b -tc

debug:
	dpkg-buildpackage -rfakeroot -us -uc -b

doc:
	rst2html doc/spec/tks-functional-spec.tks doc/spec/tks-functional-spec.html

.PHONY: build
