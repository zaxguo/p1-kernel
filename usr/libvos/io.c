// minimal user io lib 
// a thin layer over /dev/XXX and /procfs/XXX

// originally in user/uio.c, which only depends on ulib.c 
// copy it here to rebase it on libc 

// libc (newlib)
#include "fcntl.h"
#include "stdlib.h"  
#include "unistd.h"
#include "stdio.h"
#include "string.h"

#include "vos.h"

// #include "../../../kernel/fcntl.h"  // refactor this

#define LINESIZE 128    
// return 0 on success
int config_fbctl(int w, int d, int vw, int vh, int offx, int offy) {
    char buf[LINESIZE];
    int n, fbctl; 
    if ((fbctl = open("/proc/fbctl", O_RDWR)) <=0) return -1; 

    sprintf(buf, "%d %d %d %d %d %d\n", w, d, vw, vh, offx, offy); 
    n=write(fbctl,buf,strlen(buf)); 
    // printf("write returns %d\n", n);
    close(fbctl);  // flush it 
    return !(n>0); 
}

// return 0 on success. nargs: # of args parsed
int read_dispinfo(int dispinfo[MAX_DISP_ARGS], int *nargs) {
    char buf[LINESIZE], *s;
    int n; 
    int dp; 

    if ((dp = open("/proc/dispinfo", O_RDONLY)) <=0) return -1; 

    n=read(dp, buf, LINESIZE); if (n<=0) return -2;

    // parse the 1st line to a list of int args... (ignore other lines
    for (s = buf, *nargs=0; s < buf + n; s++) {
        if (*s == '\n' || *s == '\0')
            break;
        if ('0' <= *s && *s <= '9') {  // start of a num
            dispinfo[*nargs] = atoi(s); // printf("got arg %d\n", dispinfo[nargs]);
            while ('0' <= *s && *s <= '9' && s < buf + n)
                s++;
            if (++*nargs == MAX_DISP_ARGS)
                break;
        }
    }
    close(dp);  
    return 0; 
}

// 0 on success 
// read a line from /dev/events and parse it into key events
// line format: [kd|ku] 0x12
int read_kb_event(int events, int *evtype, unsigned int *scancode) {
    int n; 
    char buf[LINESIZE], *s;

    *evtype = INVALID; *scancode = 0; //invalid

    n = read(events, buf, LINESIZE); // if (n!=0) printf("read returns %d\n", n);
    if (n<=0) return -1; 
    
    s=buf;         
    if (buf[0]=='k' && buf[1]=='d') {
      *evtype = KEYDOWN; 
    } else if (buf[0]=='k' && buf[1]=='u') {
      *evtype = KEYUP; 
    } 
    s += 2; while (*s==' ') s++; 
    if (s[0]=='0' && s[1]=='x')
      *scancode = strtol(s, 0, 16); 
    return 0; 
}

// 0 on success
// not all commands use 4 args. kernel will ignore unused args
// cf kernel/sound.c procfs_parse_sbctl()
int config_sbctl(int cmd, int arg1, int arg2, int arg3) {
    char line[64]; 
    int len1; 

    int sbctl = open("/proc/sbctl", O_RDWR);
    if (sbctl <= 0) {printf("open err\n"); return -1;}
    
    sprintf(line, "%d %d %d %d\n", cmd, arg1, arg2, arg3); len1 = strlen(line); 
    if ((len1 = write(sbctl, line, len1)) < 0) {
        printf("write to sbctl failed with %d. shouldn't happen", len1);
        exit(1);
    }
    close(sbctl);   // flush
    return 0; 
}

// 0 on success
#define TXTSIZE  256 
int read_sbctl(struct sbctl_info *cfg) {
    char line[TXTSIZE]; 
    FILE *fp = fopen("/proc/sbctl", "r"); 
    if (!fp) {printf("open err\n"); return -1;}
    while (fgets(line, TXTSIZE, fp)) {
        if (line[0] == '#') 
            continue;   // skip a comment line 
        else {
            if (sscanf(line, "%d %d %d %d %d %d %d", 
                &cfg->id, &cfg->hw_fmt, &cfg->sample_rate, 
                &cfg->queue_sz, &cfg->bytes_free, &cfg->write_fmt,
                &cfg->write_channels) != 7) {
                    printf("wrong # of paras read"); fclose(fp); return -1; 
                } else {
                fclose(fp); return 0; // done
            }
        } 
    }
    printf("read file err\n"); fclose(fp); return -1;
}