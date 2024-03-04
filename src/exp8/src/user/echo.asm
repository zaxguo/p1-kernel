
echo.elf:     file format elf64-littleaarch64


Disassembly of section .text:

0000000000000000 <main>:
#include "../stat.h"
#include "user.h"

int
main(int argc, char *argv[])
{
   0:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
   4:	910003fd 	mov	x29, sp
   8:	f9000bf3 	str	x19, [sp, #16]
   c:	b9002fe0 	str	w0, [sp, #44]
  10:	f90013e1 	str	x1, [sp, #32]
  int i;

  for(i = 1; i < argc; i++){
  14:	52800020 	mov	w0, #0x1                   	// #1
  18:	b9003fe0 	str	w0, [sp, #60]
  1c:	14000023 	b	a8 <main+0xa8>
    write(1, argv[i], strlen(argv[i]));
  20:	b9803fe0 	ldrsw	x0, [sp, #60]
  24:	d37df000 	lsl	x0, x0, #3
  28:	f94013e1 	ldr	x1, [sp, #32]
  2c:	8b000020 	add	x0, x1, x0
  30:	f9400013 	ldr	x19, [x0]
  34:	b9803fe0 	ldrsw	x0, [sp, #60]
  38:	d37df000 	lsl	x0, x0, #3
  3c:	f94013e1 	ldr	x1, [sp, #32]
  40:	8b000020 	add	x0, x1, x0
  44:	f9400000 	ldr	x0, [x0]
  48:	94000053 	bl	194 <strlen>
  4c:	2a0003e2 	mov	w2, w0
  50:	aa1303e1 	mov	x1, x19
  54:	52800020 	mov	w0, #0x1                   	// #1
  58:	94000314 	bl	ca8 <write>
    if(i + 1 < argc){
  5c:	b9403fe0 	ldr	w0, [sp, #60]
  60:	11000400 	add	w0, w0, #0x1
  64:	b9402fe1 	ldr	w1, [sp, #44]
  68:	6b00003f 	cmp	w1, w0
  6c:	540000ed 	b.le	88 <main+0x88>
      write(1, " ", 1);
  70:	52800022 	mov	w2, #0x1                   	// #1
  74:	90000000 	adrp	x0, 0 <main>
  78:	9135c001 	add	x1, x0, #0xd70
  7c:	52800020 	mov	w0, #0x1                   	// #1
  80:	9400030a 	bl	ca8 <write>
  84:	14000006 	b	9c <main+0x9c>
    } else {
      write(1, "\n", 1);
  88:	52800022 	mov	w2, #0x1                   	// #1
  8c:	90000000 	adrp	x0, 0 <main>
  90:	9135e001 	add	x1, x0, #0xd78
  94:	52800020 	mov	w0, #0x1                   	// #1
  98:	94000304 	bl	ca8 <write>
  for(i = 1; i < argc; i++){
  9c:	b9403fe0 	ldr	w0, [sp, #60]
  a0:	11000400 	add	w0, w0, #0x1
  a4:	b9003fe0 	str	w0, [sp, #60]
  a8:	b9403fe1 	ldr	w1, [sp, #60]
  ac:	b9402fe0 	ldr	w0, [sp, #44]
  b0:	6b00003f 	cmp	w1, w0
  b4:	54fffb6b 	b.lt	20 <main+0x20>  // b.tstop
    }
  }
  exit(0);
  b8:	52800000 	mov	w0, #0x0                   	// #0
  bc:	940002ef 	bl	c78 <exit>

00000000000000c0 <_main>:
//
// wrapper so that it's OK if main() does not call exit().
//
void
_main()
{
  c0:	a9bf7bfd 	stp	x29, x30, [sp, #-16]!
  c4:	910003fd 	mov	x29, sp
  extern int main();
  main();
  c8:	97ffffce 	bl	0 <main>
  exit(0);
  cc:	52800000 	mov	w0, #0x0                   	// #0
  d0:	940002ea 	bl	c78 <exit>

00000000000000d4 <strcpy>:
}

char*
strcpy(char *s, const char *t)
{
  d4:	d10083ff 	sub	sp, sp, #0x20
  d8:	f90007e0 	str	x0, [sp, #8]
  dc:	f90003e1 	str	x1, [sp]
  char *os;

  os = s;
  e0:	f94007e0 	ldr	x0, [sp, #8]
  e4:	f9000fe0 	str	x0, [sp, #24]
  while((*s++ = *t++) != 0)
  e8:	d503201f 	nop
  ec:	f94003e1 	ldr	x1, [sp]
  f0:	91000420 	add	x0, x1, #0x1
  f4:	f90003e0 	str	x0, [sp]
  f8:	f94007e0 	ldr	x0, [sp, #8]
  fc:	91000402 	add	x2, x0, #0x1
 100:	f90007e2 	str	x2, [sp, #8]
 104:	39400021 	ldrb	w1, [x1]
 108:	39000001 	strb	w1, [x0]
 10c:	39400000 	ldrb	w0, [x0]
 110:	7100001f 	cmp	w0, #0x0
 114:	54fffec1 	b.ne	ec <strcpy+0x18>  // b.any
    ;
  return os;
 118:	f9400fe0 	ldr	x0, [sp, #24]
}
 11c:	910083ff 	add	sp, sp, #0x20
 120:	d65f03c0 	ret

0000000000000124 <strcmp>:

int
strcmp(const char *p, const char *q)
{
 124:	d10043ff 	sub	sp, sp, #0x10
 128:	f90007e0 	str	x0, [sp, #8]
 12c:	f90003e1 	str	x1, [sp]
  while(*p && *p == *q)
 130:	14000007 	b	14c <strcmp+0x28>
    p++, q++;
 134:	f94007e0 	ldr	x0, [sp, #8]
 138:	91000400 	add	x0, x0, #0x1
 13c:	f90007e0 	str	x0, [sp, #8]
 140:	f94003e0 	ldr	x0, [sp]
 144:	91000400 	add	x0, x0, #0x1
 148:	f90003e0 	str	x0, [sp]
  while(*p && *p == *q)
 14c:	f94007e0 	ldr	x0, [sp, #8]
 150:	39400000 	ldrb	w0, [x0]
 154:	7100001f 	cmp	w0, #0x0
 158:	540000e0 	b.eq	174 <strcmp+0x50>  // b.none
 15c:	f94007e0 	ldr	x0, [sp, #8]
 160:	39400001 	ldrb	w1, [x0]
 164:	f94003e0 	ldr	x0, [sp]
 168:	39400000 	ldrb	w0, [x0]
 16c:	6b00003f 	cmp	w1, w0
 170:	54fffe20 	b.eq	134 <strcmp+0x10>  // b.none
  return (uchar)*p - (uchar)*q;
 174:	f94007e0 	ldr	x0, [sp, #8]
 178:	39400000 	ldrb	w0, [x0]
 17c:	2a0003e1 	mov	w1, w0
 180:	f94003e0 	ldr	x0, [sp]
 184:	39400000 	ldrb	w0, [x0]
 188:	4b000020 	sub	w0, w1, w0
}
 18c:	910043ff 	add	sp, sp, #0x10
 190:	d65f03c0 	ret

0000000000000194 <strlen>:

uint
strlen(const char *s)
{
 194:	d10083ff 	sub	sp, sp, #0x20
 198:	f90007e0 	str	x0, [sp, #8]
  int n;

  for(n = 0; s[n]; n++)
 19c:	b9001fff 	str	wzr, [sp, #28]
 1a0:	14000004 	b	1b0 <strlen+0x1c>
 1a4:	b9401fe0 	ldr	w0, [sp, #28]
 1a8:	11000400 	add	w0, w0, #0x1
 1ac:	b9001fe0 	str	w0, [sp, #28]
 1b0:	b9801fe0 	ldrsw	x0, [sp, #28]
 1b4:	f94007e1 	ldr	x1, [sp, #8]
 1b8:	8b000020 	add	x0, x1, x0
 1bc:	39400000 	ldrb	w0, [x0]
 1c0:	7100001f 	cmp	w0, #0x0
 1c4:	54ffff01 	b.ne	1a4 <strlen+0x10>  // b.any
    ;
  return n;
 1c8:	b9401fe0 	ldr	w0, [sp, #28]
}
 1cc:	910083ff 	add	sp, sp, #0x20
 1d0:	d65f03c0 	ret

00000000000001d4 <memset>:

void*
memset(void *dst, int c, uint n)
{
 1d4:	d10083ff 	sub	sp, sp, #0x20
 1d8:	f90007e0 	str	x0, [sp, #8]
 1dc:	b90007e1 	str	w1, [sp, #4]
 1e0:	b90003e2 	str	w2, [sp]
  char *cdst = (char *) dst;
 1e4:	f94007e0 	ldr	x0, [sp, #8]
 1e8:	f9000be0 	str	x0, [sp, #16]
  int i;
  for(i = 0; i < n; i++){
 1ec:	b9001fff 	str	wzr, [sp, #28]
 1f0:	1400000a 	b	218 <memset+0x44>
    cdst[i] = c;
 1f4:	b9801fe0 	ldrsw	x0, [sp, #28]
 1f8:	f9400be1 	ldr	x1, [sp, #16]
 1fc:	8b000020 	add	x0, x1, x0
 200:	b94007e1 	ldr	w1, [sp, #4]
 204:	12001c21 	and	w1, w1, #0xff
 208:	39000001 	strb	w1, [x0]
  for(i = 0; i < n; i++){
 20c:	b9401fe0 	ldr	w0, [sp, #28]
 210:	11000400 	add	w0, w0, #0x1
 214:	b9001fe0 	str	w0, [sp, #28]
 218:	b9401fe0 	ldr	w0, [sp, #28]
 21c:	b94003e1 	ldr	w1, [sp]
 220:	6b00003f 	cmp	w1, w0
 224:	54fffe88 	b.hi	1f4 <memset+0x20>  // b.pmore
  }
  return dst;
 228:	f94007e0 	ldr	x0, [sp, #8]
}
 22c:	910083ff 	add	sp, sp, #0x20
 230:	d65f03c0 	ret

0000000000000234 <strchr>:

char*
strchr(const char *s, char c)
{
 234:	d10043ff 	sub	sp, sp, #0x10
 238:	f90007e0 	str	x0, [sp, #8]
 23c:	39001fe1 	strb	w1, [sp, #7]
  for(; *s; s++)
 240:	1400000b 	b	26c <strchr+0x38>
    if(*s == c)
 244:	f94007e0 	ldr	x0, [sp, #8]
 248:	39400000 	ldrb	w0, [x0]
 24c:	39401fe1 	ldrb	w1, [sp, #7]
 250:	6b00003f 	cmp	w1, w0
 254:	54000061 	b.ne	260 <strchr+0x2c>  // b.any
      return (char*)s;
 258:	f94007e0 	ldr	x0, [sp, #8]
 25c:	14000009 	b	280 <strchr+0x4c>
  for(; *s; s++)
 260:	f94007e0 	ldr	x0, [sp, #8]
 264:	91000400 	add	x0, x0, #0x1
 268:	f90007e0 	str	x0, [sp, #8]
 26c:	f94007e0 	ldr	x0, [sp, #8]
 270:	39400000 	ldrb	w0, [x0]
 274:	7100001f 	cmp	w0, #0x0
 278:	54fffe61 	b.ne	244 <strchr+0x10>  // b.any
  return 0;
 27c:	d2800000 	mov	x0, #0x0                   	// #0
}
 280:	910043ff 	add	sp, sp, #0x10
 284:	d65f03c0 	ret

0000000000000288 <gets>:

char*
gets(char *buf, int max)
{
 288:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
 28c:	910003fd 	mov	x29, sp
 290:	f9000fe0 	str	x0, [sp, #24]
 294:	b90017e1 	str	w1, [sp, #20]
  int i, cc;
  char c;

  for(i=0; i+1 < max; ){
 298:	b9002fff 	str	wzr, [sp, #44]
 29c:	14000018 	b	2fc <gets+0x74>
    cc = read(0, &c, 1);
 2a0:	91009fe0 	add	x0, sp, #0x27
 2a4:	52800022 	mov	w2, #0x1                   	// #1
 2a8:	aa0003e1 	mov	x1, x0
 2ac:	52800000 	mov	w0, #0x0                   	// #0
 2b0:	9400027b 	bl	c9c <read>
 2b4:	b9002be0 	str	w0, [sp, #40]
    if(cc < 1)
 2b8:	b9402be0 	ldr	w0, [sp, #40]
 2bc:	7100001f 	cmp	w0, #0x0
 2c0:	540002ad 	b.le	314 <gets+0x8c>
      break;
    buf[i++] = c;
 2c4:	b9402fe0 	ldr	w0, [sp, #44]
 2c8:	11000401 	add	w1, w0, #0x1
 2cc:	b9002fe1 	str	w1, [sp, #44]
 2d0:	93407c00 	sxtw	x0, w0
 2d4:	f9400fe1 	ldr	x1, [sp, #24]
 2d8:	8b000020 	add	x0, x1, x0
 2dc:	39409fe1 	ldrb	w1, [sp, #39]
 2e0:	39000001 	strb	w1, [x0]
    if(c == '\n' || c == '\r')
 2e4:	39409fe0 	ldrb	w0, [sp, #39]
 2e8:	7100281f 	cmp	w0, #0xa
 2ec:	54000160 	b.eq	318 <gets+0x90>  // b.none
 2f0:	39409fe0 	ldrb	w0, [sp, #39]
 2f4:	7100341f 	cmp	w0, #0xd
 2f8:	54000100 	b.eq	318 <gets+0x90>  // b.none
  for(i=0; i+1 < max; ){
 2fc:	b9402fe0 	ldr	w0, [sp, #44]
 300:	11000400 	add	w0, w0, #0x1
 304:	b94017e1 	ldr	w1, [sp, #20]
 308:	6b00003f 	cmp	w1, w0
 30c:	54fffcac 	b.gt	2a0 <gets+0x18>
 310:	14000002 	b	318 <gets+0x90>
      break;
 314:	d503201f 	nop
      break;
  }
  buf[i] = '\0';
 318:	b9802fe0 	ldrsw	x0, [sp, #44]
 31c:	f9400fe1 	ldr	x1, [sp, #24]
 320:	8b000020 	add	x0, x1, x0
 324:	3900001f 	strb	wzr, [x0]
  return buf;
 328:	f9400fe0 	ldr	x0, [sp, #24]
}
 32c:	a8c37bfd 	ldp	x29, x30, [sp], #48
 330:	d65f03c0 	ret

0000000000000334 <stat>:

int
stat(const char *n, struct stat *st)
{
 334:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
 338:	910003fd 	mov	x29, sp
 33c:	f9000fe0 	str	x0, [sp, #24]
 340:	f9000be1 	str	x1, [sp, #16]
  int fd;
  int r;

  fd = open(n, O_RDONLY);
 344:	52800001 	mov	w1, #0x0                   	// #0
 348:	f9400fe0 	ldr	x0, [sp, #24]
 34c:	94000263 	bl	cd8 <open>
 350:	b9002fe0 	str	w0, [sp, #44]
  if(fd < 0)
 354:	b9402fe0 	ldr	w0, [sp, #44]
 358:	7100001f 	cmp	w0, #0x0
 35c:	5400006a 	b.ge	368 <stat+0x34>  // b.tcont
    return -1;
 360:	12800000 	mov	w0, #0xffffffff            	// #-1
 364:	14000008 	b	384 <stat+0x50>
  r = fstat(fd, st);
 368:	f9400be1 	ldr	x1, [sp, #16]
 36c:	b9402fe0 	ldr	w0, [sp, #44]
 370:	94000263 	bl	cfc <fstat>
 374:	b9002be0 	str	w0, [sp, #40]
  close(fd);
 378:	b9402fe0 	ldr	w0, [sp, #44]
 37c:	9400024e 	bl	cb4 <close>
  return r;
 380:	b9402be0 	ldr	w0, [sp, #40]
}
 384:	a8c37bfd 	ldp	x29, x30, [sp], #48
 388:	d65f03c0 	ret

000000000000038c <atoi>:

int
atoi(const char *s)
{
 38c:	d10083ff 	sub	sp, sp, #0x20
 390:	f90007e0 	str	x0, [sp, #8]
  int n;

  n = 0;
 394:	b9001fff 	str	wzr, [sp, #28]
  while('0' <= *s && *s <= '9')
 398:	1400000e 	b	3d0 <atoi+0x44>
    n = n*10 + *s++ - '0';
 39c:	b9401fe1 	ldr	w1, [sp, #28]
 3a0:	2a0103e0 	mov	w0, w1
 3a4:	531e7400 	lsl	w0, w0, #2
 3a8:	0b010000 	add	w0, w0, w1
 3ac:	531f7800 	lsl	w0, w0, #1
 3b0:	2a0003e2 	mov	w2, w0
 3b4:	f94007e0 	ldr	x0, [sp, #8]
 3b8:	91000401 	add	x1, x0, #0x1
 3bc:	f90007e1 	str	x1, [sp, #8]
 3c0:	39400000 	ldrb	w0, [x0]
 3c4:	0b000040 	add	w0, w2, w0
 3c8:	5100c000 	sub	w0, w0, #0x30
 3cc:	b9001fe0 	str	w0, [sp, #28]
  while('0' <= *s && *s <= '9')
 3d0:	f94007e0 	ldr	x0, [sp, #8]
 3d4:	39400000 	ldrb	w0, [x0]
 3d8:	7100bc1f 	cmp	w0, #0x2f
 3dc:	540000a9 	b.ls	3f0 <atoi+0x64>  // b.plast
 3e0:	f94007e0 	ldr	x0, [sp, #8]
 3e4:	39400000 	ldrb	w0, [x0]
 3e8:	7100e41f 	cmp	w0, #0x39
 3ec:	54fffd89 	b.ls	39c <atoi+0x10>  // b.plast
  return n;
 3f0:	b9401fe0 	ldr	w0, [sp, #28]
}
 3f4:	910083ff 	add	sp, sp, #0x20
 3f8:	d65f03c0 	ret

00000000000003fc <memmove>:

void*
memmove(void *vdst, const void *vsrc, int n)
{
 3fc:	d100c3ff 	sub	sp, sp, #0x30
 400:	f9000fe0 	str	x0, [sp, #24]
 404:	f9000be1 	str	x1, [sp, #16]
 408:	b9000fe2 	str	w2, [sp, #12]
  char *dst;
  const char *src;

  dst = vdst;
 40c:	f9400fe0 	ldr	x0, [sp, #24]
 410:	f90017e0 	str	x0, [sp, #40]
  src = vsrc;
 414:	f9400be0 	ldr	x0, [sp, #16]
 418:	f90013e0 	str	x0, [sp, #32]
  if (src > dst) {
 41c:	f94013e1 	ldr	x1, [sp, #32]
 420:	f94017e0 	ldr	x0, [sp, #40]
 424:	eb00003f 	cmp	x1, x0
 428:	54000209 	b.ls	468 <memmove+0x6c>  // b.plast
    while(n-- > 0)
 42c:	14000009 	b	450 <memmove+0x54>
      *dst++ = *src++;
 430:	f94013e1 	ldr	x1, [sp, #32]
 434:	91000420 	add	x0, x1, #0x1
 438:	f90013e0 	str	x0, [sp, #32]
 43c:	f94017e0 	ldr	x0, [sp, #40]
 440:	91000402 	add	x2, x0, #0x1
 444:	f90017e2 	str	x2, [sp, #40]
 448:	39400021 	ldrb	w1, [x1]
 44c:	39000001 	strb	w1, [x0]
    while(n-- > 0)
 450:	b9400fe0 	ldr	w0, [sp, #12]
 454:	51000401 	sub	w1, w0, #0x1
 458:	b9000fe1 	str	w1, [sp, #12]
 45c:	7100001f 	cmp	w0, #0x0
 460:	54fffe8c 	b.gt	430 <memmove+0x34>
 464:	14000019 	b	4c8 <memmove+0xcc>
  } else {
    dst += n;
 468:	b9800fe0 	ldrsw	x0, [sp, #12]
 46c:	f94017e1 	ldr	x1, [sp, #40]
 470:	8b000020 	add	x0, x1, x0
 474:	f90017e0 	str	x0, [sp, #40]
    src += n;
 478:	b9800fe0 	ldrsw	x0, [sp, #12]
 47c:	f94013e1 	ldr	x1, [sp, #32]
 480:	8b000020 	add	x0, x1, x0
 484:	f90013e0 	str	x0, [sp, #32]
    while(n-- > 0)
 488:	1400000b 	b	4b4 <memmove+0xb8>
      *--dst = *--src;
 48c:	f94013e0 	ldr	x0, [sp, #32]
 490:	d1000400 	sub	x0, x0, #0x1
 494:	f90013e0 	str	x0, [sp, #32]
 498:	f94017e0 	ldr	x0, [sp, #40]
 49c:	d1000400 	sub	x0, x0, #0x1
 4a0:	f90017e0 	str	x0, [sp, #40]
 4a4:	f94013e0 	ldr	x0, [sp, #32]
 4a8:	39400001 	ldrb	w1, [x0]
 4ac:	f94017e0 	ldr	x0, [sp, #40]
 4b0:	39000001 	strb	w1, [x0]
    while(n-- > 0)
 4b4:	b9400fe0 	ldr	w0, [sp, #12]
 4b8:	51000401 	sub	w1, w0, #0x1
 4bc:	b9000fe1 	str	w1, [sp, #12]
 4c0:	7100001f 	cmp	w0, #0x0
 4c4:	54fffe4c 	b.gt	48c <memmove+0x90>
  }
  return vdst;
 4c8:	f9400fe0 	ldr	x0, [sp, #24]
}
 4cc:	9100c3ff 	add	sp, sp, #0x30
 4d0:	d65f03c0 	ret

00000000000004d4 <memcmp>:

int
memcmp(const void *s1, const void *s2, uint n)
{
 4d4:	d100c3ff 	sub	sp, sp, #0x30
 4d8:	f9000fe0 	str	x0, [sp, #24]
 4dc:	f9000be1 	str	x1, [sp, #16]
 4e0:	b9000fe2 	str	w2, [sp, #12]
  const char *p1 = s1, *p2 = s2;
 4e4:	f9400fe0 	ldr	x0, [sp, #24]
 4e8:	f90017e0 	str	x0, [sp, #40]
 4ec:	f9400be0 	ldr	x0, [sp, #16]
 4f0:	f90013e0 	str	x0, [sp, #32]
  while (n-- > 0) {
 4f4:	14000014 	b	544 <memcmp+0x70>
    if (*p1 != *p2) {
 4f8:	f94017e0 	ldr	x0, [sp, #40]
 4fc:	39400001 	ldrb	w1, [x0]
 500:	f94013e0 	ldr	x0, [sp, #32]
 504:	39400000 	ldrb	w0, [x0]
 508:	6b00003f 	cmp	w1, w0
 50c:	54000100 	b.eq	52c <memcmp+0x58>  // b.none
      return *p1 - *p2;
 510:	f94017e0 	ldr	x0, [sp, #40]
 514:	39400000 	ldrb	w0, [x0]
 518:	2a0003e1 	mov	w1, w0
 51c:	f94013e0 	ldr	x0, [sp, #32]
 520:	39400000 	ldrb	w0, [x0]
 524:	4b000020 	sub	w0, w1, w0
 528:	1400000d 	b	55c <memcmp+0x88>
    }
    p1++;
 52c:	f94017e0 	ldr	x0, [sp, #40]
 530:	91000400 	add	x0, x0, #0x1
 534:	f90017e0 	str	x0, [sp, #40]
    p2++;
 538:	f94013e0 	ldr	x0, [sp, #32]
 53c:	91000400 	add	x0, x0, #0x1
 540:	f90013e0 	str	x0, [sp, #32]
  while (n-- > 0) {
 544:	b9400fe0 	ldr	w0, [sp, #12]
 548:	51000401 	sub	w1, w0, #0x1
 54c:	b9000fe1 	str	w1, [sp, #12]
 550:	7100001f 	cmp	w0, #0x0
 554:	54fffd21 	b.ne	4f8 <memcmp+0x24>  // b.any
  }
  return 0;
 558:	52800000 	mov	w0, #0x0                   	// #0
}
 55c:	9100c3ff 	add	sp, sp, #0x30
 560:	d65f03c0 	ret

0000000000000564 <memcpy>:

void *
memcpy(void *dst, const void *src, uint n)
{
 564:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
 568:	910003fd 	mov	x29, sp
 56c:	f90017e0 	str	x0, [sp, #40]
 570:	f90013e1 	str	x1, [sp, #32]
 574:	b9001fe2 	str	w2, [sp, #28]
  return memmove(dst, src, n);
 578:	b9401fe0 	ldr	w0, [sp, #28]
 57c:	2a0003e2 	mov	w2, w0
 580:	f94013e1 	ldr	x1, [sp, #32]
 584:	f94017e0 	ldr	x0, [sp, #40]
 588:	97ffff9d 	bl	3fc <memmove>
}
 58c:	a8c37bfd 	ldp	x29, x30, [sp], #48
 590:	d65f03c0 	ret

0000000000000594 <putc>:

static char digits[] = "0123456789ABCDEF";

static void
putc(int fd, char c)
{
 594:	a9be7bfd 	stp	x29, x30, [sp, #-32]!
 598:	910003fd 	mov	x29, sp
 59c:	b9001fe0 	str	w0, [sp, #28]
 5a0:	39006fe1 	strb	w1, [sp, #27]
  write(fd, &c, 1);
 5a4:	91006fe0 	add	x0, sp, #0x1b
 5a8:	52800022 	mov	w2, #0x1                   	// #1
 5ac:	aa0003e1 	mov	x1, x0
 5b0:	b9401fe0 	ldr	w0, [sp, #28]
 5b4:	940001bd 	bl	ca8 <write>
}
 5b8:	d503201f 	nop
 5bc:	a8c27bfd 	ldp	x29, x30, [sp], #32
 5c0:	d65f03c0 	ret

00000000000005c4 <printint>:

static void
printint(int fd, int xx, int base, int sgn)
{
 5c4:	a9bc7bfd 	stp	x29, x30, [sp, #-64]!
 5c8:	910003fd 	mov	x29, sp
 5cc:	b9001fe0 	str	w0, [sp, #28]
 5d0:	b9001be1 	str	w1, [sp, #24]
 5d4:	b90017e2 	str	w2, [sp, #20]
 5d8:	b90013e3 	str	w3, [sp, #16]
  char buf[16];
  int i, neg;
  uint x;

  neg = 0;
 5dc:	b9003bff 	str	wzr, [sp, #56]
  if(sgn && xx < 0){
 5e0:	b94013e0 	ldr	w0, [sp, #16]
 5e4:	7100001f 	cmp	w0, #0x0
 5e8:	54000140 	b.eq	610 <printint+0x4c>  // b.none
 5ec:	b9401be0 	ldr	w0, [sp, #24]
 5f0:	7100001f 	cmp	w0, #0x0
 5f4:	540000ea 	b.ge	610 <printint+0x4c>  // b.tcont
    neg = 1;
 5f8:	52800020 	mov	w0, #0x1                   	// #1
 5fc:	b9003be0 	str	w0, [sp, #56]
    x = -xx;
 600:	b9401be0 	ldr	w0, [sp, #24]
 604:	4b0003e0 	neg	w0, w0
 608:	b90037e0 	str	w0, [sp, #52]
 60c:	14000003 	b	618 <printint+0x54>
  } else {
    x = xx;
 610:	b9401be0 	ldr	w0, [sp, #24]
 614:	b90037e0 	str	w0, [sp, #52]
  }

  i = 0;
 618:	b9003fff 	str	wzr, [sp, #60]
  do{
    buf[i++] = digits[x % base];
 61c:	b94017e1 	ldr	w1, [sp, #20]
 620:	b94037e0 	ldr	w0, [sp, #52]
 624:	1ac10802 	udiv	w2, w0, w1
 628:	1b017c41 	mul	w1, w2, w1
 62c:	4b010003 	sub	w3, w0, w1
 630:	b9403fe0 	ldr	w0, [sp, #60]
 634:	11000401 	add	w1, w0, #0x1
 638:	b9003fe1 	str	w1, [sp, #60]
 63c:	b0000001 	adrp	x1, 1000 <uptime+0x2a4>
 640:	9108c022 	add	x2, x1, #0x230
 644:	2a0303e1 	mov	w1, w3
 648:	38616842 	ldrb	w2, [x2, x1]
 64c:	93407c00 	sxtw	x0, w0
 650:	910083e1 	add	x1, sp, #0x20
 654:	38206822 	strb	w2, [x1, x0]
  }while((x /= base) != 0);
 658:	b94017e0 	ldr	w0, [sp, #20]
 65c:	b94037e1 	ldr	w1, [sp, #52]
 660:	1ac00820 	udiv	w0, w1, w0
 664:	b90037e0 	str	w0, [sp, #52]
 668:	b94037e0 	ldr	w0, [sp, #52]
 66c:	7100001f 	cmp	w0, #0x0
 670:	54fffd61 	b.ne	61c <printint+0x58>  // b.any
  if(neg)
 674:	b9403be0 	ldr	w0, [sp, #56]
 678:	7100001f 	cmp	w0, #0x0
 67c:	540001e0 	b.eq	6b8 <printint+0xf4>  // b.none
    buf[i++] = '-';
 680:	b9403fe0 	ldr	w0, [sp, #60]
 684:	11000401 	add	w1, w0, #0x1
 688:	b9003fe1 	str	w1, [sp, #60]
 68c:	93407c00 	sxtw	x0, w0
 690:	910083e1 	add	x1, sp, #0x20
 694:	528005a2 	mov	w2, #0x2d                  	// #45
 698:	38206822 	strb	w2, [x1, x0]

  while(--i >= 0)
 69c:	14000007 	b	6b8 <printint+0xf4>
    putc(fd, buf[i]);
 6a0:	b9803fe0 	ldrsw	x0, [sp, #60]
 6a4:	910083e1 	add	x1, sp, #0x20
 6a8:	38606820 	ldrb	w0, [x1, x0]
 6ac:	2a0003e1 	mov	w1, w0
 6b0:	b9401fe0 	ldr	w0, [sp, #28]
 6b4:	97ffffb8 	bl	594 <putc>
  while(--i >= 0)
 6b8:	b9403fe0 	ldr	w0, [sp, #60]
 6bc:	51000400 	sub	w0, w0, #0x1
 6c0:	b9003fe0 	str	w0, [sp, #60]
 6c4:	b9403fe0 	ldr	w0, [sp, #60]
 6c8:	7100001f 	cmp	w0, #0x0
 6cc:	54fffeaa 	b.ge	6a0 <printint+0xdc>  // b.tcont
}
 6d0:	d503201f 	nop
 6d4:	d503201f 	nop
 6d8:	a8c47bfd 	ldp	x29, x30, [sp], #64
 6dc:	d65f03c0 	ret

00000000000006e0 <printptr>:

static void
printptr(int fd, uint64 x) {
 6e0:	a9bd7bfd 	stp	x29, x30, [sp, #-48]!
 6e4:	910003fd 	mov	x29, sp
 6e8:	b9001fe0 	str	w0, [sp, #28]
 6ec:	f9000be1 	str	x1, [sp, #16]
  int i;
  putc(fd, '0');
 6f0:	52800601 	mov	w1, #0x30                  	// #48
 6f4:	b9401fe0 	ldr	w0, [sp, #28]
 6f8:	97ffffa7 	bl	594 <putc>
  putc(fd, 'x');
 6fc:	52800f01 	mov	w1, #0x78                  	// #120
 700:	b9401fe0 	ldr	w0, [sp, #28]
 704:	97ffffa4 	bl	594 <putc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
 708:	b9002fff 	str	wzr, [sp, #44]
 70c:	1400000f 	b	748 <printptr+0x68>
    putc(fd, digits[x >> (sizeof(uint64) * 8 - 4)]);
 710:	f9400be0 	ldr	x0, [sp, #16]
 714:	d37cfc00 	lsr	x0, x0, #60
 718:	b0000001 	adrp	x1, 1000 <uptime+0x2a4>
 71c:	9108c021 	add	x1, x1, #0x230
 720:	38606820 	ldrb	w0, [x1, x0]
 724:	2a0003e1 	mov	w1, w0
 728:	b9401fe0 	ldr	w0, [sp, #28]
 72c:	97ffff9a 	bl	594 <putc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
 730:	b9402fe0 	ldr	w0, [sp, #44]
 734:	11000400 	add	w0, w0, #0x1
 738:	b9002fe0 	str	w0, [sp, #44]
 73c:	f9400be0 	ldr	x0, [sp, #16]
 740:	d37cec00 	lsl	x0, x0, #4
 744:	f9000be0 	str	x0, [sp, #16]
 748:	b9402fe0 	ldr	w0, [sp, #44]
 74c:	71003c1f 	cmp	w0, #0xf
 750:	54fffe09 	b.ls	710 <printptr+0x30>  // b.plast
}
 754:	d503201f 	nop
 758:	d503201f 	nop
 75c:	a8c37bfd 	ldp	x29, x30, [sp], #48
 760:	d65f03c0 	ret

0000000000000764 <vprintf>:

// Print to the given fd. Only understands %d, %x, %p, %s.
void
vprintf(int fd, const char *fmt, va_list ap)
{
 764:	a9bb7bfd 	stp	x29, x30, [sp, #-80]!
 768:	910003fd 	mov	x29, sp
 76c:	f9000bf3 	str	x19, [sp, #16]
 770:	b9002fe0 	str	w0, [sp, #44]
 774:	f90013e1 	str	x1, [sp, #32]
 778:	aa0203f3 	mov	x19, x2
  char *s;
  int c, i, state;

  state = 0;
 77c:	b90043ff 	str	wzr, [sp, #64]
  for(i = 0; fmt[i]; i++){
 780:	b90047ff 	str	wzr, [sp, #68]
 784:	140000ed 	b	b38 <vprintf+0x3d4>
    c = fmt[i] & 0xff;
 788:	b98047e0 	ldrsw	x0, [sp, #68]
 78c:	f94013e1 	ldr	x1, [sp, #32]
 790:	8b000020 	add	x0, x1, x0
 794:	39400000 	ldrb	w0, [x0]
 798:	b9003fe0 	str	w0, [sp, #60]
    if(state == 0){
 79c:	b94043e0 	ldr	w0, [sp, #64]
 7a0:	7100001f 	cmp	w0, #0x0
 7a4:	540001a1 	b.ne	7d8 <vprintf+0x74>  // b.any
      if(c == '%'){
 7a8:	b9403fe0 	ldr	w0, [sp, #60]
 7ac:	7100941f 	cmp	w0, #0x25
 7b0:	54000081 	b.ne	7c0 <vprintf+0x5c>  // b.any
        state = '%';
 7b4:	528004a0 	mov	w0, #0x25                  	// #37
 7b8:	b90043e0 	str	w0, [sp, #64]
 7bc:	140000dc 	b	b2c <vprintf+0x3c8>
      } else {
        putc(fd, c);
 7c0:	b9403fe0 	ldr	w0, [sp, #60]
 7c4:	12001c00 	and	w0, w0, #0xff
 7c8:	2a0003e1 	mov	w1, w0
 7cc:	b9402fe0 	ldr	w0, [sp, #44]
 7d0:	97ffff71 	bl	594 <putc>
 7d4:	140000d6 	b	b2c <vprintf+0x3c8>
      }
    } else if(state == '%'){
 7d8:	b94043e0 	ldr	w0, [sp, #64]
 7dc:	7100941f 	cmp	w0, #0x25
 7e0:	54001a61 	b.ne	b2c <vprintf+0x3c8>  // b.any
      if(c == 'd'){
 7e4:	b9403fe0 	ldr	w0, [sp, #60]
 7e8:	7101901f 	cmp	w0, #0x64
 7ec:	54000381 	b.ne	85c <vprintf+0xf8>  // b.any
        printint(fd, va_arg(ap, int), 10, 1);
 7f0:	b9401a61 	ldr	w1, [x19, #24]
 7f4:	f9400260 	ldr	x0, [x19]
 7f8:	7100003f 	cmp	w1, #0x0
 7fc:	540000ab 	b.lt	810 <vprintf+0xac>  // b.tstop
 800:	91002c01 	add	x1, x0, #0xb
 804:	927df021 	and	x1, x1, #0xfffffffffffffff8
 808:	f9000261 	str	x1, [x19]
 80c:	1400000d 	b	840 <vprintf+0xdc>
 810:	11002022 	add	w2, w1, #0x8
 814:	b9001a62 	str	w2, [x19, #24]
 818:	b9401a62 	ldr	w2, [x19, #24]
 81c:	7100005f 	cmp	w2, #0x0
 820:	540000ad 	b.le	834 <vprintf+0xd0>
 824:	91002c01 	add	x1, x0, #0xb
 828:	927df021 	and	x1, x1, #0xfffffffffffffff8
 82c:	f9000261 	str	x1, [x19]
 830:	14000004 	b	840 <vprintf+0xdc>
 834:	f9400662 	ldr	x2, [x19, #8]
 838:	93407c20 	sxtw	x0, w1
 83c:	8b000040 	add	x0, x2, x0
 840:	b9400000 	ldr	w0, [x0]
 844:	52800023 	mov	w3, #0x1                   	// #1
 848:	52800142 	mov	w2, #0xa                   	// #10
 84c:	2a0003e1 	mov	w1, w0
 850:	b9402fe0 	ldr	w0, [sp, #44]
 854:	97ffff5c 	bl	5c4 <printint>
 858:	140000b4 	b	b28 <vprintf+0x3c4>
      } else if(c == 'l') {
 85c:	b9403fe0 	ldr	w0, [sp, #60]
 860:	7101b01f 	cmp	w0, #0x6c
 864:	54000381 	b.ne	8d4 <vprintf+0x170>  // b.any
        printint(fd, va_arg(ap, uint64), 10, 0);
 868:	b9401a61 	ldr	w1, [x19, #24]
 86c:	f9400260 	ldr	x0, [x19]
 870:	7100003f 	cmp	w1, #0x0
 874:	540000ab 	b.lt	888 <vprintf+0x124>  // b.tstop
 878:	91003c01 	add	x1, x0, #0xf
 87c:	927df021 	and	x1, x1, #0xfffffffffffffff8
 880:	f9000261 	str	x1, [x19]
 884:	1400000d 	b	8b8 <vprintf+0x154>
 888:	11002022 	add	w2, w1, #0x8
 88c:	b9001a62 	str	w2, [x19, #24]
 890:	b9401a62 	ldr	w2, [x19, #24]
 894:	7100005f 	cmp	w2, #0x0
 898:	540000ad 	b.le	8ac <vprintf+0x148>
 89c:	91003c01 	add	x1, x0, #0xf
 8a0:	927df021 	and	x1, x1, #0xfffffffffffffff8
 8a4:	f9000261 	str	x1, [x19]
 8a8:	14000004 	b	8b8 <vprintf+0x154>
 8ac:	f9400662 	ldr	x2, [x19, #8]
 8b0:	93407c20 	sxtw	x0, w1
 8b4:	8b000040 	add	x0, x2, x0
 8b8:	f9400000 	ldr	x0, [x0]
 8bc:	52800003 	mov	w3, #0x0                   	// #0
 8c0:	52800142 	mov	w2, #0xa                   	// #10
 8c4:	2a0003e1 	mov	w1, w0
 8c8:	b9402fe0 	ldr	w0, [sp, #44]
 8cc:	97ffff3e 	bl	5c4 <printint>
 8d0:	14000096 	b	b28 <vprintf+0x3c4>
      } else if(c == 'x') {
 8d4:	b9403fe0 	ldr	w0, [sp, #60]
 8d8:	7101e01f 	cmp	w0, #0x78
 8dc:	54000381 	b.ne	94c <vprintf+0x1e8>  // b.any
        printint(fd, va_arg(ap, int), 16, 0);
 8e0:	b9401a61 	ldr	w1, [x19, #24]
 8e4:	f9400260 	ldr	x0, [x19]
 8e8:	7100003f 	cmp	w1, #0x0
 8ec:	540000ab 	b.lt	900 <vprintf+0x19c>  // b.tstop
 8f0:	91002c01 	add	x1, x0, #0xb
 8f4:	927df021 	and	x1, x1, #0xfffffffffffffff8
 8f8:	f9000261 	str	x1, [x19]
 8fc:	1400000d 	b	930 <vprintf+0x1cc>
 900:	11002022 	add	w2, w1, #0x8
 904:	b9001a62 	str	w2, [x19, #24]
 908:	b9401a62 	ldr	w2, [x19, #24]
 90c:	7100005f 	cmp	w2, #0x0
 910:	540000ad 	b.le	924 <vprintf+0x1c0>
 914:	91002c01 	add	x1, x0, #0xb
 918:	927df021 	and	x1, x1, #0xfffffffffffffff8
 91c:	f9000261 	str	x1, [x19]
 920:	14000004 	b	930 <vprintf+0x1cc>
 924:	f9400662 	ldr	x2, [x19, #8]
 928:	93407c20 	sxtw	x0, w1
 92c:	8b000040 	add	x0, x2, x0
 930:	b9400000 	ldr	w0, [x0]
 934:	52800003 	mov	w3, #0x0                   	// #0
 938:	52800202 	mov	w2, #0x10                  	// #16
 93c:	2a0003e1 	mov	w1, w0
 940:	b9402fe0 	ldr	w0, [sp, #44]
 944:	97ffff20 	bl	5c4 <printint>
 948:	14000078 	b	b28 <vprintf+0x3c4>
      } else if(c == 'p') {
 94c:	b9403fe0 	ldr	w0, [sp, #60]
 950:	7101c01f 	cmp	w0, #0x70
 954:	54000341 	b.ne	9bc <vprintf+0x258>  // b.any
        printptr(fd, va_arg(ap, uint64));
 958:	b9401a61 	ldr	w1, [x19, #24]
 95c:	f9400260 	ldr	x0, [x19]
 960:	7100003f 	cmp	w1, #0x0
 964:	540000ab 	b.lt	978 <vprintf+0x214>  // b.tstop
 968:	91003c01 	add	x1, x0, #0xf
 96c:	927df021 	and	x1, x1, #0xfffffffffffffff8
 970:	f9000261 	str	x1, [x19]
 974:	1400000d 	b	9a8 <vprintf+0x244>
 978:	11002022 	add	w2, w1, #0x8
 97c:	b9001a62 	str	w2, [x19, #24]
 980:	b9401a62 	ldr	w2, [x19, #24]
 984:	7100005f 	cmp	w2, #0x0
 988:	540000ad 	b.le	99c <vprintf+0x238>
 98c:	91003c01 	add	x1, x0, #0xf
 990:	927df021 	and	x1, x1, #0xfffffffffffffff8
 994:	f9000261 	str	x1, [x19]
 998:	14000004 	b	9a8 <vprintf+0x244>
 99c:	f9400662 	ldr	x2, [x19, #8]
 9a0:	93407c20 	sxtw	x0, w1
 9a4:	8b000040 	add	x0, x2, x0
 9a8:	f9400000 	ldr	x0, [x0]
 9ac:	aa0003e1 	mov	x1, x0
 9b0:	b9402fe0 	ldr	w0, [sp, #44]
 9b4:	97ffff4b 	bl	6e0 <printptr>
 9b8:	1400005c 	b	b28 <vprintf+0x3c4>
      } else if(c == 's'){
 9bc:	b9403fe0 	ldr	w0, [sp, #60]
 9c0:	7101cc1f 	cmp	w0, #0x73
 9c4:	54000561 	b.ne	a70 <vprintf+0x30c>  // b.any
        s = va_arg(ap, char*);
 9c8:	b9401a61 	ldr	w1, [x19, #24]
 9cc:	f9400260 	ldr	x0, [x19]
 9d0:	7100003f 	cmp	w1, #0x0
 9d4:	540000ab 	b.lt	9e8 <vprintf+0x284>  // b.tstop
 9d8:	91003c01 	add	x1, x0, #0xf
 9dc:	927df021 	and	x1, x1, #0xfffffffffffffff8
 9e0:	f9000261 	str	x1, [x19]
 9e4:	1400000d 	b	a18 <vprintf+0x2b4>
 9e8:	11002022 	add	w2, w1, #0x8
 9ec:	b9001a62 	str	w2, [x19, #24]
 9f0:	b9401a62 	ldr	w2, [x19, #24]
 9f4:	7100005f 	cmp	w2, #0x0
 9f8:	540000ad 	b.le	a0c <vprintf+0x2a8>
 9fc:	91003c01 	add	x1, x0, #0xf
 a00:	927df021 	and	x1, x1, #0xfffffffffffffff8
 a04:	f9000261 	str	x1, [x19]
 a08:	14000004 	b	a18 <vprintf+0x2b4>
 a0c:	f9400662 	ldr	x2, [x19, #8]
 a10:	93407c20 	sxtw	x0, w1
 a14:	8b000040 	add	x0, x2, x0
 a18:	f9400000 	ldr	x0, [x0]
 a1c:	f90027e0 	str	x0, [sp, #72]
        if(s == 0)
 a20:	f94027e0 	ldr	x0, [sp, #72]
 a24:	f100001f 	cmp	x0, #0x0
 a28:	540001a1 	b.ne	a5c <vprintf+0x2f8>  // b.any
          s = "(null)";
 a2c:	90000000 	adrp	x0, 0 <main>
 a30:	91360000 	add	x0, x0, #0xd80
 a34:	f90027e0 	str	x0, [sp, #72]
        while(*s != 0){
 a38:	14000009 	b	a5c <vprintf+0x2f8>
          putc(fd, *s);
 a3c:	f94027e0 	ldr	x0, [sp, #72]
 a40:	39400000 	ldrb	w0, [x0]
 a44:	2a0003e1 	mov	w1, w0
 a48:	b9402fe0 	ldr	w0, [sp, #44]
 a4c:	97fffed2 	bl	594 <putc>
          s++;
 a50:	f94027e0 	ldr	x0, [sp, #72]
 a54:	91000400 	add	x0, x0, #0x1
 a58:	f90027e0 	str	x0, [sp, #72]
        while(*s != 0){
 a5c:	f94027e0 	ldr	x0, [sp, #72]
 a60:	39400000 	ldrb	w0, [x0]
 a64:	7100001f 	cmp	w0, #0x0
 a68:	54fffea1 	b.ne	a3c <vprintf+0x2d8>  // b.any
 a6c:	1400002f 	b	b28 <vprintf+0x3c4>
        }
      } else if(c == 'c'){
 a70:	b9403fe0 	ldr	w0, [sp, #60]
 a74:	71018c1f 	cmp	w0, #0x63
 a78:	54000361 	b.ne	ae4 <vprintf+0x380>  // b.any
        putc(fd, va_arg(ap, uint));
 a7c:	b9401a61 	ldr	w1, [x19, #24]
 a80:	f9400260 	ldr	x0, [x19]
 a84:	7100003f 	cmp	w1, #0x0
 a88:	540000ab 	b.lt	a9c <vprintf+0x338>  // b.tstop
 a8c:	91002c01 	add	x1, x0, #0xb
 a90:	927df021 	and	x1, x1, #0xfffffffffffffff8
 a94:	f9000261 	str	x1, [x19]
 a98:	1400000d 	b	acc <vprintf+0x368>
 a9c:	11002022 	add	w2, w1, #0x8
 aa0:	b9001a62 	str	w2, [x19, #24]
 aa4:	b9401a62 	ldr	w2, [x19, #24]
 aa8:	7100005f 	cmp	w2, #0x0
 aac:	540000ad 	b.le	ac0 <vprintf+0x35c>
 ab0:	91002c01 	add	x1, x0, #0xb
 ab4:	927df021 	and	x1, x1, #0xfffffffffffffff8
 ab8:	f9000261 	str	x1, [x19]
 abc:	14000004 	b	acc <vprintf+0x368>
 ac0:	f9400662 	ldr	x2, [x19, #8]
 ac4:	93407c20 	sxtw	x0, w1
 ac8:	8b000040 	add	x0, x2, x0
 acc:	b9400000 	ldr	w0, [x0]
 ad0:	12001c00 	and	w0, w0, #0xff
 ad4:	2a0003e1 	mov	w1, w0
 ad8:	b9402fe0 	ldr	w0, [sp, #44]
 adc:	97fffeae 	bl	594 <putc>
 ae0:	14000012 	b	b28 <vprintf+0x3c4>
      } else if(c == '%'){
 ae4:	b9403fe0 	ldr	w0, [sp, #60]
 ae8:	7100941f 	cmp	w0, #0x25
 aec:	540000e1 	b.ne	b08 <vprintf+0x3a4>  // b.any
        putc(fd, c);
 af0:	b9403fe0 	ldr	w0, [sp, #60]
 af4:	12001c00 	and	w0, w0, #0xff
 af8:	2a0003e1 	mov	w1, w0
 afc:	b9402fe0 	ldr	w0, [sp, #44]
 b00:	97fffea5 	bl	594 <putc>
 b04:	14000009 	b	b28 <vprintf+0x3c4>
      } else {
        // Unknown % sequence.  Print it to draw attention.
        putc(fd, '%');
 b08:	528004a1 	mov	w1, #0x25                  	// #37
 b0c:	b9402fe0 	ldr	w0, [sp, #44]
 b10:	97fffea1 	bl	594 <putc>
        putc(fd, c);
 b14:	b9403fe0 	ldr	w0, [sp, #60]
 b18:	12001c00 	and	w0, w0, #0xff
 b1c:	2a0003e1 	mov	w1, w0
 b20:	b9402fe0 	ldr	w0, [sp, #44]
 b24:	97fffe9c 	bl	594 <putc>
      }
      state = 0;
 b28:	b90043ff 	str	wzr, [sp, #64]
  for(i = 0; fmt[i]; i++){
 b2c:	b94047e0 	ldr	w0, [sp, #68]
 b30:	11000400 	add	w0, w0, #0x1
 b34:	b90047e0 	str	w0, [sp, #68]
 b38:	b98047e0 	ldrsw	x0, [sp, #68]
 b3c:	f94013e1 	ldr	x1, [sp, #32]
 b40:	8b000020 	add	x0, x1, x0
 b44:	39400000 	ldrb	w0, [x0]
 b48:	7100001f 	cmp	w0, #0x0
 b4c:	54ffe1e1 	b.ne	788 <vprintf+0x24>  // b.any
    }
  }
}
 b50:	d503201f 	nop
 b54:	d503201f 	nop
 b58:	f9400bf3 	ldr	x19, [sp, #16]
 b5c:	a8c57bfd 	ldp	x29, x30, [sp], #80
 b60:	d65f03c0 	ret

0000000000000b64 <fprintf>:

void
fprintf(int fd, const char *fmt, ...)
{
 b64:	a9b77bfd 	stp	x29, x30, [sp, #-144]!
 b68:	910003fd 	mov	x29, sp
 b6c:	b9003fe0 	str	w0, [sp, #60]
 b70:	f9001be1 	str	x1, [sp, #48]
 b74:	f90033e2 	str	x2, [sp, #96]
 b78:	f90037e3 	str	x3, [sp, #104]
 b7c:	f9003be4 	str	x4, [sp, #112]
 b80:	f9003fe5 	str	x5, [sp, #120]
 b84:	f90043e6 	str	x6, [sp, #128]
 b88:	f90047e7 	str	x7, [sp, #136]
  va_list ap;

  va_start(ap, fmt);
 b8c:	910243e0 	add	x0, sp, #0x90
 b90:	f90023e0 	str	x0, [sp, #64]
 b94:	910243e0 	add	x0, sp, #0x90
 b98:	f90027e0 	str	x0, [sp, #72]
 b9c:	910183e0 	add	x0, sp, #0x60
 ba0:	f9002be0 	str	x0, [sp, #80]
 ba4:	128005e0 	mov	w0, #0xffffffd0            	// #-48
 ba8:	b9005be0 	str	w0, [sp, #88]
 bac:	b9005fff 	str	wzr, [sp, #92]
  vprintf(fd, fmt, ap);
 bb0:	910043e2 	add	x2, sp, #0x10
 bb4:	910103e3 	add	x3, sp, #0x40
 bb8:	a9400460 	ldp	x0, x1, [x3]
 bbc:	a9000440 	stp	x0, x1, [x2]
 bc0:	a9410460 	ldp	x0, x1, [x3, #16]
 bc4:	a9010440 	stp	x0, x1, [x2, #16]
 bc8:	910043e0 	add	x0, sp, #0x10
 bcc:	aa0003e2 	mov	x2, x0
 bd0:	f9401be1 	ldr	x1, [sp, #48]
 bd4:	b9403fe0 	ldr	w0, [sp, #60]
 bd8:	97fffee3 	bl	764 <vprintf>
}
 bdc:	d503201f 	nop
 be0:	a8c97bfd 	ldp	x29, x30, [sp], #144
 be4:	d65f03c0 	ret

0000000000000be8 <printf>:

void
printf(const char *fmt, ...)
{
 be8:	a9b67bfd 	stp	x29, x30, [sp, #-160]!
 bec:	910003fd 	mov	x29, sp
 bf0:	f9001fe0 	str	x0, [sp, #56]
 bf4:	f90037e1 	str	x1, [sp, #104]
 bf8:	f9003be2 	str	x2, [sp, #112]
 bfc:	f9003fe3 	str	x3, [sp, #120]
 c00:	f90043e4 	str	x4, [sp, #128]
 c04:	f90047e5 	str	x5, [sp, #136]
 c08:	f9004be6 	str	x6, [sp, #144]
 c0c:	f9004fe7 	str	x7, [sp, #152]
  va_list ap;

  va_start(ap, fmt);
 c10:	910283e0 	add	x0, sp, #0xa0
 c14:	f90023e0 	str	x0, [sp, #64]
 c18:	910283e0 	add	x0, sp, #0xa0
 c1c:	f90027e0 	str	x0, [sp, #72]
 c20:	910183e0 	add	x0, sp, #0x60
 c24:	f9002be0 	str	x0, [sp, #80]
 c28:	128006e0 	mov	w0, #0xffffffc8            	// #-56
 c2c:	b9005be0 	str	w0, [sp, #88]
 c30:	b9005fff 	str	wzr, [sp, #92]
  vprintf(1, fmt, ap);
 c34:	910043e2 	add	x2, sp, #0x10
 c38:	910103e3 	add	x3, sp, #0x40
 c3c:	a9400460 	ldp	x0, x1, [x3]
 c40:	a9000440 	stp	x0, x1, [x2]
 c44:	a9410460 	ldp	x0, x1, [x3, #16]
 c48:	a9010440 	stp	x0, x1, [x2, #16]
 c4c:	910043e0 	add	x0, sp, #0x10
 c50:	aa0003e2 	mov	x2, x0
 c54:	f9401fe1 	ldr	x1, [sp, #56]
 c58:	52800020 	mov	w0, #0x1                   	// #1
 c5c:	97fffec2 	bl	764 <vprintf>
}
 c60:	d503201f 	nop
 c64:	a8ca7bfd 	ldp	x29, x30, [sp], #160
 c68:	d65f03c0 	ret

0000000000000c6c <fork>:
 c6c:	d2800028 	mov	x8, #0x1                   	// #1
 c70:	d4000001 	svc	#0x0
 c74:	d65f03c0 	ret

0000000000000c78 <exit>:
 c78:	d2800048 	mov	x8, #0x2                   	// #2
 c7c:	d4000001 	svc	#0x0
 c80:	d65f03c0 	ret

0000000000000c84 <wait>:
 c84:	d2800068 	mov	x8, #0x3                   	// #3
 c88:	d4000001 	svc	#0x0
 c8c:	d65f03c0 	ret

0000000000000c90 <pipe>:
 c90:	d2800088 	mov	x8, #0x4                   	// #4
 c94:	d4000001 	svc	#0x0
 c98:	d65f03c0 	ret

0000000000000c9c <read>:
 c9c:	d28000a8 	mov	x8, #0x5                   	// #5
 ca0:	d4000001 	svc	#0x0
 ca4:	d65f03c0 	ret

0000000000000ca8 <write>:
 ca8:	d2800208 	mov	x8, #0x10                  	// #16
 cac:	d4000001 	svc	#0x0
 cb0:	d65f03c0 	ret

0000000000000cb4 <close>:
 cb4:	d28002a8 	mov	x8, #0x15                  	// #21
 cb8:	d4000001 	svc	#0x0
 cbc:	d65f03c0 	ret

0000000000000cc0 <kill>:
 cc0:	d28000c8 	mov	x8, #0x6                   	// #6
 cc4:	d4000001 	svc	#0x0
 cc8:	d65f03c0 	ret

0000000000000ccc <exec>:
 ccc:	d28000e8 	mov	x8, #0x7                   	// #7
 cd0:	d4000001 	svc	#0x0
 cd4:	d65f03c0 	ret

0000000000000cd8 <open>:
 cd8:	d28001e8 	mov	x8, #0xf                   	// #15
 cdc:	d4000001 	svc	#0x0
 ce0:	d65f03c0 	ret

0000000000000ce4 <mknod>:
 ce4:	d2800228 	mov	x8, #0x11                  	// #17
 ce8:	d4000001 	svc	#0x0
 cec:	d65f03c0 	ret

0000000000000cf0 <unlink>:
 cf0:	d2800248 	mov	x8, #0x12                  	// #18
 cf4:	d4000001 	svc	#0x0
 cf8:	d65f03c0 	ret

0000000000000cfc <fstat>:
 cfc:	d2800108 	mov	x8, #0x8                   	// #8
 d00:	d4000001 	svc	#0x0
 d04:	d65f03c0 	ret

0000000000000d08 <link>:
 d08:	d2800268 	mov	x8, #0x13                  	// #19
 d0c:	d4000001 	svc	#0x0
 d10:	d65f03c0 	ret

0000000000000d14 <mkdir>:
 d14:	d2800288 	mov	x8, #0x14                  	// #20
 d18:	d4000001 	svc	#0x0
 d1c:	d65f03c0 	ret

0000000000000d20 <chdir>:
 d20:	d2800128 	mov	x8, #0x9                   	// #9
 d24:	d4000001 	svc	#0x0
 d28:	d65f03c0 	ret

0000000000000d2c <dup>:
 d2c:	d2800148 	mov	x8, #0xa                   	// #10
 d30:	d4000001 	svc	#0x0
 d34:	d65f03c0 	ret

0000000000000d38 <getpid>:
 d38:	d2800168 	mov	x8, #0xb                   	// #11
 d3c:	d4000001 	svc	#0x0
 d40:	d65f03c0 	ret

0000000000000d44 <sbrk>:
 d44:	d2800188 	mov	x8, #0xc                   	// #12
 d48:	d4000001 	svc	#0x0
 d4c:	d65f03c0 	ret

0000000000000d50 <sleep>:
 d50:	d28001a8 	mov	x8, #0xd                   	// #13
 d54:	d4000001 	svc	#0x0
 d58:	d65f03c0 	ret

0000000000000d5c <uptime>:
 d5c:	d28001c8 	mov	x8, #0xe                   	// #14
 d60:	d4000001 	svc	#0x0
 d64:	d65f03c0 	ret
