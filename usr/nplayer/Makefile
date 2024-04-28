# depends on libc, libnew, libminidsl, libvorbis

include $(abspath ../../config.mk)

PROG = nplayer

OBJS = nplayer.o

# do visualization on screen? (use sdl) 
COPS += -DHAS_VISUAL

# gcc options
COPS += -MMD -Wall -Werror -g -fno-omit-frame-pointer
COPS += -nostdinc -nostdlib -nostartfiles -ffreestanding
COPS += -O0

# gcc specific 
COPS += -I /usr/lib/gcc-cross/aarch64-linux-gnu/9/include/

# lib dep
COPS += -I $(NEWLIB_INC_PATH)
COPS += -I $(LIBNEW_PATH)
COPS += -I $(LIBVORBIS_PATH)
COPS += -I $(LIBMINISDL_PATH)/include

LDFLAGS = -static -T ../user.ld -nostdlib -nostartfiles -ffreestanding -static
LDFLAGS += -L $(NEWLIB_BUILD_PATH)
LDFLAGS += -L $(LIBVORBIS_PATH)
LDFLAGS += -L $(LIBNEW_PATH)
LDFLAGS += -L $(LIBMINISDL_PATH)

# note the order
LIBS += -lvorbis -lminisdl -lnew
LIBS += -lm
LIBS += -lc
LIBS += -lgcc

all: $(PROG)

$(PROG): $(OBJS)
	$(CC) $(LDFLAGS) $(OBJS) $(LIBS)  -o $@

%.o: %.c
	$(CC) $(COPS) -o $@ -c $<

clean:
	rm -f $(OBJS) $(PROG)
