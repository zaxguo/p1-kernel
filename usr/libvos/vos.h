// For non-standard OS interfaces, e.g. not part of libc
// referenced by user apps (c and cpp)

#ifndef _VOS_H
#define _VOS_H

#ifdef __cplusplus
extern "C" {
#endif
/////////////// uio.c
// USB keyboard 
enum{INVALID=0,KEYDOWN,KEYUP}; // evtype below
int read_kb_event(int events, int *evtype, unsigned *scancode);

// display config
// the field of /proc/dispinfo. order must be right
// check by "cat /proc/dispinfo"
enum{WIDTH=0,HEIGHT,VWIDTH,VHEIGHT,SWIDTH,SHEIGHT,
    PITCH,DEPTH,ISRGB,MAX_DISP_ARGS}; 
int config_fbctl(int w, int d, int vw, int vh, int offx, int offy);
int read_dispinfo(int dispinfo[MAX_DISP_ARGS], int *nargs);

// /proc/sbctl
struct sbctl_info {
    int id;
    int hw_fmt;
    int sample_rate; 
    int queue_sz; 
    int bytes_free; 
    int write_fmt;
    int write_channels; 
}; 
int read_sbctl(struct sbctl_info *cfg); 
int config_sbctl(int cmd, int arg1, int arg2, int arg3); 

// /proc/sbctl command, cf kernel/sound.c
enum {
  SB_CMD_FINI = 0, 
  SB_CMD_INIT, 
  SB_CMD_START, 
  SB_CMD_CANCEL, 
  SB_CMD_WR_FMT, 
  SB_CMD_TEST = 9
}; 

#define CLONE_VM	0x00000100		// linux/sched.h

// syscall.c
extern unsigned int uptime_ms(void);  
extern unsigned int msleep(unsigned int msec); 

// semaphores. see kernel sys_semcreate() for design comments
// direct call syscalls, as they have no libc wrappers
int sys_semcreate(int count); 
int sys_semfree(int id); 
int sys_semp(int id); // P()
int sys_semv(int id); // V()

// not in libc (newlib)
// https://man7.org/linux/man-pages/man2/clone.2.html#NOTES
// return -1 on failure, otherwise pid (or 0)
int clone(int (*fn)(void *), void *stack, int flags, void *arg); 

#ifdef __cplusplus
} // extern "C"
#endif // __cplusplus

#endif // _VOS_H