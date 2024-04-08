#ifndef _FCNTL_H
#define _FCNTL_H

// also included by user source
#define O_RDONLY  0x000
#define O_WRONLY  0x001
#define O_RDWR    0x002
#define O_CREATE  0x200
#define O_TRUNC   0x400

#define	SEEK_SET	0	/* set file offset to offset */
#define	SEEK_CUR	1	/* set file offset to current plus offset */
#define	SEEK_END	2	/* set file offset to EOF plus offset */

// major num for devices
// modeled after: https://github.com/NJU-ProjectN/navy-apps/blob/master/README.md
// TODO: make procfs a seperate file type (not just a major dev number...)
enum {
  CONSOLE = 1, 
  KEYBOARD,
  FRAMEBUFFER,  // /dev/fb
  DEVNULL,  // /dev/null
  DEVZERO,     // /dev/zero
  DEVSB,    // /dev/sb, sound buffer
  // procfs below
  PROCFS_DISPINFO, 
  PROCFS_CPUINFO,
  PROCFS_MEMINFO, 
  PROCFS_FBCTL, 
  PROCFS_SBCTL,   
  NDEV    // max
};

struct proc_dev_info {
  char type;
#define TYPE_DEVFS  0  
#define TYPE_PROCFS  1
  int major;
  const char * path; // 0 no specific path
}; 

// lookup table. define as macro here so that it can be included
// in both user & kernel. and the macro is only instantiated in specific files 
// as needed. 
#define PROC_DEV_TABLE  \
static struct proc_dev_info pdi[] =            \
{                                       \
  {.type = TYPE_DEVFS, .major = CONSOLE, .path = "/dev/console"}, \
  {.type = TYPE_DEVFS, .major = KEYBOARD, .path = "/dev/events"},  \
  {.type = TYPE_DEVFS, .major = FRAMEBUFFER, .path = "/dev/fb"},\
  {.type = TYPE_DEVFS, .major = DEVNULL, .path = "/dev/null"}, \
  {.type = TYPE_DEVFS, .major = DEVZERO, .path = "/dev/zero"}, \
  {.type = TYPE_DEVFS, .major = DEVSB, .path = "/dev/sb"}, \
  {.type = TYPE_PROCFS, .major = PROCFS_DISPINFO, .path = "/proc/dispinfo"}, \
  {.type = TYPE_PROCFS, .major = PROCFS_CPUINFO, .path = "/proc/cpuinfo"},   \
  {.type = TYPE_PROCFS, .major = PROCFS_MEMINFO, .path = "/proc/meminfo"},   \
  {.type = TYPE_PROCFS, .major = PROCFS_FBCTL, .path = "/proc/fbctl"},       \
  {.type = TYPE_PROCFS, .major = PROCFS_SBCTL, .path = "/proc/sbctl"},        \
};

#endif