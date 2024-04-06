#include <stdbool.h>
#include <stdint.h>
#include <math.h>

#include "common.h"

#define STB_VORBIS_NO_PUSHDATA_API
#define STB_VORBIS_NO_CRT
#define assert(x)
int errno;
#include <stdlib.h>
#include <string.h>
#include "stb_vorbis.c"		// xzl: direct include c... no header file??

extern unsigned char music_ogg[];		// xzl: music buf
extern unsigned int music_ogg_len;

static bool initialized = false;
static int len = 0;

static char tmpbuf[1 << 18];    // 256 KiB		// xzl: vorbis working buf?
static short *music = 0x6000000;			//xzl: decoded music buf. to be written to

static inline void initialize()
{
	initialized = true;

	// Turn on LED
	DSB();
	*GPFSEL4 |= (1 << 21);
	*GPCLR1 = (1 << 15);

	int err;
	stb_vorbis_alloc alloc = {
		.alloc_buffer = tmpbuf,
		.alloc_buffer_length_in_bytes = sizeof tmpbuf,
	};
	stb_vorbis *v = stb_vorbis_open_memory(music_ogg, music_ogg_len, &err, &alloc);
	int ch = v->channels;

	// 64 MiB, stores ~6 minutes of stereo audio
	int total = 32 << 20;
	int offset = 0;
	len = 0;
	while (1) {
		int n = stb_vorbis_get_frame_short_interleaved(v, ch, music + offset, total - offset);
		if (n == 0) break;
		len += n;
		offset += n * ch;
	}
	stb_vorbis_close(v);

	*GPSET1 = (1 << 15);
	DMB();
}

// xzl: every time called, will return a "chunk_size" of data...?? but how to continuous play?
unsigned synth(int16_t **o_buf, unsigned chunk_size)
{
	if (!initialized) initialize();

	static int16_t buf[8192];
	*o_buf = &buf[0];				//xzl: o_buf: output buf? 

	static uint32_t phase = 0;
	for (unsigned i = 0; i < chunk_size; i += 2) {		// xzl??? fill buf with music?
		buf[i] = music[phase];
		buf[i + 1] = music[phase + 1];
		if ((phase += 2) >= len * 2) phase = 0;	// xzl: advance phase...
	}

	return chunk_size;
}
