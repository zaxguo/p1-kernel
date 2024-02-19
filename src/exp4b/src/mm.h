#ifndef	_MM_H
#define	_MM_H

unsigned long get_free_page();
void free_page(unsigned long p);
void memzero(unsigned long src, unsigned long n);

#endif  /*_MM_H */
