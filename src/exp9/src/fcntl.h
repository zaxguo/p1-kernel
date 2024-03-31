// also included by user source
#define O_RDONLY  0x000
#define O_WRONLY  0x001
#define O_RDWR    0x002
#define O_CREATE  0x200
#define O_TRUNC   0x400


// major num for devices
// modeled after: https://github.com/NJU-ProjectN/navy-apps/blob/master/README.md
// TODO: make procfs a seperate file type (not just a major dev number...)
enum {
  CONSOLE = 1, 
  KEYBOARD,
  FRAMEBUFFER,  
  DEVNULL,  // /dev/null
  DEVZERO,     // /dev/zero
  PROCFS_DISPINFO, 
  PROCFS_CPUINFO,
  PROCFS_MEMINFO, 
  PROCFS_FBCTL, 
  NDEV    // max
};
