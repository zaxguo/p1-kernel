# a music player program
# dependency: libc, libminisdl, libvorbis

include $(abspath ../../config.mk)

PROG = nplayer

OBJS = nplayer.o

# do visualization on screen?
CFLAGS += -DHAS_VISUAL

# gcc options
CFLAGS += -MMD -Wall -Werror -g -fno-omit-frame-pointer
CFLAGS += -nostdinc -nostdlib -nostartfiles -ffreestanding
CFLAGS += -O2

# gcc specific 
CFLAGS += -I /usr/lib/gcc-cross/aarch64-linux-gnu/9/include/

# lib dependency
LIBDEP += $(LIBC_BUILD_PATH)/libm.a
LIBDEP += $(LIBC_BUILD_PATH)/libc.a
LIBDEP += $(LIB_BUILD_PATH)/libvos.a
LIBDEP += $(LIB_BUILD_PATH)/libminisdl.a
LIBDEP += $(LIB_BUILD_PATH)/libvorbis.a

# lib inc 
CFLAGS += -I $(LIBC_INC_PATH)
CFLAGS += -I $(LIBVOS_PATH)
CFLAGS += -I $(LIBVORBIS_PATH)
CFLAGS += -I $(LIBMINISDL_PATH)/include

LDFLAGS = -static -T ../user.ld -nostdlib -nostartfiles -ffreestanding -static
LDFLAGS += -L $(LIBC_BUILD_PATH)
LDFLAGS += -L $(LIB_BUILD_PATH)

# note the order
LIBS += -lvorbis -lminisdl -lvos
LIBS += -lm
LIBS += -lc
LIBS += -lgcc

all: $(PROG)

$(PROG): $(OBJS) $(LIBDEP)
	$(VB) $(CC) $(LDFLAGS) $(CRT0) $(OBJS) $(LIBS)  -o $@

%.o: %.c
	$(VB) $(CC) $(CFLAGS) -o $@ -c $<

clean:
	rm -f $(OBJS) $(PROG)
