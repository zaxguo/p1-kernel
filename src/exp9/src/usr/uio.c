// minimal user io lib 
// a thin layer over /dev/XXX and /procfs/XXX

#include "../param.h"   // only need types
#include "user.h"

#define LINESIZE 128    

// return 0 on success
int config_fbctl(int fbctl, int w, int d, int vw, int vh) {
    char buf[LINESIZE];
    int n; 

    sprintf(buf, "%d %d %d %d\n", w, d, vw, vh); 
    n=write(fbctl,buf,LINESIZE); 
    return !(n>0); 
}

// return # of int args parsed; 0 on failure
int read_dispinfo(int dp, int dispinfo[MAX_DISP_ARGS]) {
    char buf[LINESIZE], *s;
    int n, nargs; 

    n=read(dp, buf, LINESIZE); if (n<=0) return 0;

    // parse the 1st line to a list of int args... (ignore other lines
    for (s = buf, nargs=0; s < buf + n; s++) {
        if (*s == '\n' || *s == '\0')
            break;
        if ('0' <= *s && *s <= '9') {  // start of a num
            dispinfo[nargs] = atoi(s); // printf("got arg %d\n", dispinfo[nargs]);
            while ('0' <= *s && *s <= '9' && s < buf + n)
                s++;
            if (++nargs == MAX_DISP_ARGS)
                break;
        }
    }

    return nargs; 
}

// 0 on success 
// read a line from /dev/events and parse it into key events
// line format: [kd|ku] 0x12
int read_kb_event(int events, int *evtype, unsigned int *scancode) {
    int n; 
    char buf[LINESIZE], *s;

    *evtype = INVALID; *scancode = 0; //invalid

    n = read(events, buf, LINESIZE); if (n<=0) return -1; 
    s=buf;         
    if (buf[0]=='k' && buf[1]=='d') {
      *evtype = KEYDOWN; 
    } else if (buf[0]=='k' && buf[1]=='u') {
      *evtype = KEYUP; 
    } 
    s += 2; while (*s==' ') s++; 
    if (s[0]=='0' && s[1]=='x')
      *scancode = atoi16(s); 
    return 0; 
}

