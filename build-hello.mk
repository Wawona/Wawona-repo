
HELLO_VERSION := 2.10

hello-setup:
	curl -L -o hello-$(HELLO_VERSION).tar.gz http://ftpmirror.gnu.org/gnu/hello/hello-$(HELLO_VERSION).tar.gz
	tar -xf hello-$(HELLO_VERSION).tar.gz

hello:
	cd hello-$(HELLO_VERSION) && ./configure
	cd hello-$(HELLO_VERSION) && make

hello-package: hello
	mkdir -p build/hello
	cd hello-$(HELLO_VERSION) && make install DESTDIR=$(PWD)/build/hello
	tar -czf hello-$(HELLO_VERSION).tar.gz -C build/hello .
