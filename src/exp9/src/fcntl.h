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
  PROCFS_DISPINFO, 
  PROCFS_CPUINFO,
  PROCFS_MEMINFO, 
  PROCFS_FBCTL, 
  PROCFS_SBCTL,   
  NDEV    // max
};
