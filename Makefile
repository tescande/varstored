TARGET = varstored

OBJS :=	device.o \
	handler.o \
	pci.o \
	varstored.o \
	xapidb.o

CFLAGS  = -I$(shell pwd)/include

# _GNU_SOURCE for asprintf.
CFLAGS += -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_GNU_SOURCE

CFLAGS += -DXC_WANT_COMPAT_MAP_FOREIGN_API=1 -DXC_WANT_COMPAT_EVTCHN_API=1 -DXC_WANT_COMPAT_DEVICEMODEL_API=1

CFLAGS += $$(pkg-config --cflags libxml-2.0)

CFLAGS += -Wall -g -O1 

ifeq ($(shell uname),Linux)
LDLIBS := -lutil -lrt
endif

LDLIBS += -lxenstore -lxenctrl -lcrypto $$(pkg-config --libs libxml-2.0)

# Get gcc to generate the dependencies for us.
CFLAGS   += -Wp,-MD,$(@D)/.$(@F).d

SUBDIRS  = $(filter-out ./,$(dir $(OBJS) $(LIBS)))
DEPS     = .*.d

LDFLAGS := -g 

all: $(TARGET)

$(TARGET): $(LIBS) $(OBJS)
	gcc -o $@ $(LDFLAGS) $(OBJS) $(LIBS) $(LDLIBS)

%.o: %.c
	gcc -o $@ $(CFLAGS) -c $<

check: testPK.pem testPK.key testPK2.pem testPK2.key
	gcc -Wall -g -o test test.c $$(pkg-config --cflags --libs glib-2.0) -lcrypto
	./test

.PHONY: check

AUTHS = PK.auth KEK.auth db.auth
auth: $(AUTHS)

.PHONY: auth

create-auth: create-auth.c
	gcc -Wall -o create-auth create-auth.c -lcrypto

%.pem %.key:
	openssl req -new -x509 -newkey rsa:2048 -subj "/CN=$*/" -keyout $*.key -out $*.pem -days 36500 -nodes -sha256

PK.auth: create-auth PK.pem PK.key
	./create-auth -k PK.key -c PK.pem PK PK.auth PK.pem

KEK.auth: create-auth PK.pem PK.key KEK.list
	./create-auth -k PK.key -c PK.pem KEK KEK.auth $$(cat KEK.list)

db.auth: create-auth PK.pem PK.key db.list
	./create-auth -k PK.key -c PK.pem db db.auth $$(cat db.list)

clean:
	$(foreach dir,$(SUBDIRS),make -C $(dir) clean)
	rm -f $(OBJS)
	rm -f $(DEPS)
	rm -f $(TARGET)
	rm -f TAGS
	rm -f test test.dat testPK.pem testPK.key testPK2.pem testPK2.key
	rm -f $(AUTHS)
	rm -f create-auth
	rm -f PK.pem PK.key

.PHONY: TAGS
TAGS:
	find . -name \*.[ch] | etags -

-include $(DEPS)

print-%:
	echo $($*)
