all: build

clean:
	fakeroot make -f debian/rules clean
	rm doc/spec/*.html

build:
	dpkg-buildpackage -rfakeroot -us -uc -b -tc

debug:
	dpkg-buildpackage -rfakeroot -us -uc -b

docs:
	rst2html doc/spec/tks-functional-spec.rst doc/spec/tks-functional-spec.html

.PHONY: build
