GRML_DEBOOTSTRAP_VERSION=latest
GRML_DEBOOTSTRAP_LOCAL_PATH=$(shell pwd)/local_dir

CFLAGS ?= -ggdb -O2 -Wall -Wextra -Wno-unused-parameter
CFLAGS += -fPIC -fvisibility=hidden
LDLIBS ?=
LDLIBS += -ldl

PLUGIN = fake-uname.so

$(PLUGIN): fake-uname.c
	$(CC) $(CFLAGS) $(LDFLAGS) $< $(LDLIBS) -o $@ -shared

UNAME_CHECK = LD_PRELOAD="$(CURDIR)/$(PLUGIN)" uname

check: $(PLUGIN)
	echo "$(UNAME_CHECK)"
	test "0.0.0" = "$(shell $(UNAME_CHECK) -r)"
	test "1.2.3" = "$(shell UTS_RELEASE="1.2.3" $(UNAME_CHECK) -r)"

install:
	cd .. && make DESTDIR=packer/local_dir install

clean:
	$(RM) *.o *.so
	rm -rf local_dir

# Debian 12
bookworm: clean fake-uname.so install
	packer build -var debian_version=$@ -var grml_debootstrap_version=$(GRML_DEBOOTSTRAP_VERSION) -var grml_debootstrap_local_path=$(GRML_DEBOOTSTRAP_LOCAL_PATH) debian64.json

# Debian 11
bullseye: clean fake-uname.so install
	packer build -var debian_version=$@ -var grml_debootstrap_version=$(GRML_DEBOOTSTRAP_VERSION) -var grml_debootstrap_local_path=$(GRML_DEBOOTSTRAP_LOCAL_PATH) debian64.json

# Debian 10
buster: clean fake-uname.so install
	packer build -var debian_version=$@ -var grml_debootstrap_version=$(GRML_DEBOOTSTRAP_VERSION) -var grml_debootstrap_local_path=$(GRML_DEBOOTSTRAP_LOCAL_PATH) debian64.json

# Debian 9
stretch: clean fake-uname.so install
	packer build -var debian_version=$@ -var grml_debootstrap_version=$(GRML_DEBOOTSTRAP_VERSION) -var grml_debootstrap_local_path=$(GRML_DEBOOTSTRAP_LOCAL_PATH) debian64.json

# Debian 8
jessie: clean fake-uname.so install
	packer build -var debian_version=$@ -var grml_debootstrap_version=$(GRML_DEBOOTSTRAP_VERSION) -var grml_debootstrap_local_path=$(GRML_DEBOOTSTRAP_LOCAL_PATH) debian64.json

# Debian 7
wheezy: clean fake-uname.so install
	packer build -var debian_version=$@ -var grml_debootstrap_version=$(GRML_DEBOOTSTRAP_VERSION) -var grml_debootstrap_local_path=$(GRML_DEBOOTSTRAP_LOCAL_PATH) debian64.json

# Debian 6.0
squeeze: clean fake-uname.so install
	packer build -var debian_version=$@ -var grml_debootstrap_version=$(GRML_DEBOOTSTRAP_VERSION) -var grml_debootstrap_local_path=$(GRML_DEBOOTSTRAP_LOCAL_PATH) debian64.json

# Debian 5.0
lenny: clean fake-uname.so install
	packer build -var debian_version=$@ -var grml_debootstrap_version=$(GRML_DEBOOTSTRAP_VERSION) -var grml_debootstrap_local_path=$(GRML_DEBOOTSTRAP_LOCAL_PATH) debian64.json

.PHONY: compile bullseye buster stretch jessie wheezy squeeze lenny
.NOTPARALLEL:
