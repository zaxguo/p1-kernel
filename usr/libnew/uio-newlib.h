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
struct sbctl_config {
    int id;
    int hw_fmt;
    int sample_rate; 
    int queue_sz; 
    int bytes_free; 
    int write_fmt;
    int write_channels; 
}; 
int read_sbctl(struct sbctl_config *cfg); 