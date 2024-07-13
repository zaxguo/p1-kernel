#include "plat.h"
#include "utils.h"
#include "mmu.h"
#include "spinlock.h"

// kernel memory allocator

/* 
	Minimalist page allocation 

	all alloc/free funcs below are locked
*/
static unsigned char mem_map [ MAX_PAGING_PAGES ] = {0,};
struct spinlock alloc_lock = {.locked=0, .cpu=0, .name="alloc_lock"}; 
static unsigned long LOW_MEMORY = 0; 	// pa
static unsigned long PAGING_PAGES = 0; 
extern char kernel_end; // linker.ld

// allocated from paging area, for malloc()/free()
//  define 0 to disable malloc()
#define MALLOC_PAGES  (8*1024*1024 / PAGE_SIZE)  
#undef MEM_PAGE_ALLOC

/* allocate a page (zero filled). return kernel va. */
void *kalloc() {
	unsigned long page = get_free_page();
	if (page == 0)
		return 0;
	return PA2VA(page);
}

/* free p which is kernel va */
void kfree(void *p) {
	free_page(VA2PA(p));
}

/* allocate a page (zero filled). return pa of the page. 0 if failed */
unsigned long get_free_page() {
	acquire(&alloc_lock);
	for (int i = 0; i < PAGING_PAGES; i++){
		if (mem_map[i] == 0){
			mem_map[i] = 1;
			release(&alloc_lock);
			unsigned long page = LOW_MEMORY + i*PAGE_SIZE;
			memzero_aligned(PA2VA(page), PAGE_SIZE);
			return page;
		}
	}
	release(&alloc_lock);
	return 0;
}

/* free a page. @p is pa of the page. */
void free_page(unsigned long p){
	acquire(&alloc_lock);
	mem_map[(p - LOW_MEMORY) / PAGE_SIZE] = 0;
	release(&alloc_lock);
}

static void alloc_init (unsigned char *ulBase, unsigned long ulSize); 

// reserve a phys region. all pages must be unused previously. 
// caller must hold alloc_lock
// is_reserve==1 for reserve, 0 for free
// return 0 if succeeds
static int _reserve_phys_region(unsigned long pa_start, 
	unsigned long size, int is_reserve) {
	if ((pa_start & ~PAGE_MASK) != 0 || (size & ~PAGE_MASK) != 0)
		{W("pa_start %lx size %lx", pa_start, size);BUG(); return -1;}
	for (unsigned i = (pa_start>>PAGE_SHIFT); i<(size>>PAGE_SHIFT); i++){
		if (mem_map[i] == is_reserve)	
			{return -2;}      // page already taken?   
	}	
	for (unsigned i = (pa_start>>PAGE_SHIFT); i<(size>>PAGE_SHIFT); i++)
		mem_map[i] = is_reserve; 
	return 0; 
}

int reserve_phys_region(unsigned long pa_start, unsigned long size) {
	int ret; 
	acquire(&alloc_lock); 
	ret = _reserve_phys_region(pa_start, size, 1/*is_reserve*/);
	release(&alloc_lock); 
	return ret; 
}

int free_phys_region(unsigned long pa_start, unsigned long size) {
	int ret; 
	acquire(&alloc_lock); 
	ret = _reserve_phys_region(pa_start, size, 0/*is_reserve*/);
	release(&alloc_lock); 
	return ret; 
}

// return: # of paging pages
unsigned int paging_init() {
	LOW_MEMORY = VA2PA(PGROUNDUP((unsigned long)&kernel_end));	
	PAGING_PAGES = (HIGH_MEMORY - LOW_MEMORY) / PAGE_SIZE; 
	
    BUG_ON(2 * MALLOC_PAGES >= PAGING_PAGES); // too many malloc pages 

	I("phys mem: %08x -- %08x", PHYS_BASE, PHYS_BASE + PHYS_SIZE);
	I("	kernel: %08x -- %08lx", KERNEL_START, VA2PA(&kernel_end));
	I("	paging mem: %08lx -- %08x", LOW_MEMORY, HIGH_MEMORY);
	I("     %lu%s %ld pages", 
		int_val((HIGH_MEMORY - LOW_MEMORY)),
		int_postfix((HIGH_MEMORY - LOW_MEMORY)),
		PAGING_PAGES);

    // reserve a virtually contig region for malloc(). 
    if (MALLOC_PAGES) {
        acquire(&alloc_lock); 
        // for (int i = 0; i < MALLOC_PAGES; i++) {
        //     BUG_ON(mem_map[i]);      // page already taken?
        //     mem_map[i] = 1;             
        // }
		// int ret = _reserve_phys_region(LOW_MEMORY, MALLOC_PAGES * PAGE_SIZE); 
		// BUG_ON(ret); 
        // alloc_init(PA2VA(LOW_MEMORY), MALLOC_PAGES * PAGE_SIZE); 
		int ret = _reserve_phys_region(HIGH_MEMORY-MALLOC_PAGES*PAGE_SIZE, 
			MALLOC_PAGES*PAGE_SIZE, 1); 
		BUG_ON(ret); 
        alloc_init(PA2VA(HIGH_MEMORY-MALLOC_PAGES*PAGE_SIZE), 
			MALLOC_PAGES*PAGE_SIZE); 		
        release(&alloc_lock);
    } 
    I("     malloc area: %lu%s", int_val(MALLOC_PAGES * PAGE_SIZE),
                                 int_postfix(MALLOC_PAGES * PAGE_SIZE)); 

	return PAGING_PAGES; 
}

//////////// kernel malloc/free. right now only for usbc. may spinoff in the future 
// USPi - An USB driver for Raspberry Pi written in C
// alloc.c   cf LICENSE

#define MEM_DEBUG	1	// xzl: malloc statics (per blocksize)
// below also has a page allocator, if we replace our simple page alloc in the future
// #define MEM_PAGE_ALLOC 1   // disabled as of now

#define BLOCK_ALIGN	16
#define ALIGN_MASK	(BLOCK_ALIGN-1)

// prefix the actual data (not embedded)
typedef struct TBlockHeader
{
	unsigned int	nMagic		__attribute__ ((packed));		//4
#define BLOCK_MAGIC	0x424C4D43	
	unsigned int	nSize		__attribute__ ((packed));		//4
	struct TBlockHeader *pNext	__attribute__ ((packed));		//8 for aarch64
	// unsigned int	nPadding	__attribute__ ((packed));	
	unsigned char	Data[0];	// actual data follows, shall align to BLOCK_ALIGN
} TBlockHeader;			

// a freelist of blks, of same size.
typedef struct TBlockBucket {
	unsigned int	nSize;
#ifdef MEM_DEBUG
	unsigned int	nCount;		// already allocated (off the freelist)
	unsigned int	nMaxCount;
#endif
	TBlockHeader	*pFreeList;
} TBlockBucket;

#ifdef MEM_PAGE_ALLOC
typedef struct TFreePage {
	unsigned int	nMagic;
#define FREEPAGE_MAGIC	0x50474D43
	struct TFreePage *pNext;
} TFreePage;

typedef struct TPageBucket {
#ifdef MEM_DEBUG
	unsigned int	nCount;
	unsigned int	nMaxCount;
#endif
	TFreePage	*pFreeList;
} TPageBucket;
#endif

static unsigned char *s_pNextBlock = 0;		// base of the global chunk. BLOCK_ALIGN aligned
static unsigned char *s_pBlockLimit = 0;	// end of it

#ifdef MEM_PAGE_ALLOC
static unsigned char *s_pNextPage;
static unsigned char *s_pPageLimit;
#endif

// mutiple lists for diff sizes...
static TBlockBucket s_BlockBucket[] = {{0x40}, {0x400}, {0x1000}, {0x4000}, 
							{0x40000}, {0x80000}, {0}};
#define MAX_ALLOC_SIZE 0x80000		// largest bucket size. malloc() cannot exceed this size

#ifdef MEM_PAGE_ALLOC
static TPageBucket s_PageBucket;		// a freelist of pages...
#endif

// the region to be managed by malloc. must be kernel va. 
//          must be page aligned?
static void alloc_init (unsigned char *ulBase, unsigned long ulSize) {
#if 0       // xzl: not needed
	if (ulBase < MEM_HEAP_START) {
		ulBase = MEM_HEAP_START;
	}
	ulSize = ulLimit - ulBase;
#endif

#ifdef MEM_PAGE_ALLOC
    unsigned char *ulLimit = ulBase + ulSize;
	unsigned long ulQuarterSize = ulSize / 4;
	// xzl: 1/4 mem goes under malloc, otehrs goes under page alloc. hardcoded
	s_pNextBlock = (unsigned char *) ulBase;
	s_pBlockLimit = (unsigned char *) (ulBase + ulQuarterSize);

	s_pNextPage = (unsigned char *) ((ulBase + ulQuarterSize + PAGE_SIZE) & ~PAGE_MASK);
	s_pPageLimit = (unsigned char *) ulLimit;
#else
	s_pNextBlock = (unsigned char *) ulBase;
	s_pBlockLimit = (unsigned char *) (ulBase + ulSize);
#endif
}

// return total mem (both under malloc and page alloc)
unsigned long mem_get_size (void) {
#ifdef MEM_PAGE_ALLOC
	return (unsigned long) (s_pBlockLimit - s_pNextBlock) + (s_pPageLimit - s_pNextPage);
#else
	return (unsigned long) (s_pBlockLimit - s_pNextBlock);
#endif
}

void *malloc (unsigned ulSize) {
	assert (s_pNextBlock != 0);
	if (ulSize > MAX_ALLOC_SIZE) 
		return 0; 
		
    // unsigned long origsize = ulSize; //xzl        
	acquire(&alloc_lock);

	TBlockBucket *pBucket; // round up to smallest block size
	for (pBucket = s_BlockBucket; pBucket->nSize > 0; pBucket++) {
		if (ulSize <= pBucket->nSize) {
			ulSize = pBucket->nSize;
			break;
		}
	}

	TBlockHeader *pBlockHeader; // the free block to return
	if (   pBucket->nSize > 0
	    && (pBlockHeader = pBucket->pFreeList) != 0) { // found a block, spin it off
		assert (pBlockHeader->nMagic == BLOCK_MAGIC);
		pBucket->pFreeList = pBlockHeader->pNext;
	} else { 
		// either no freelist w/ large enough sizes (pBucket->nSize 0) (already 
        //  excluded by checking alloc size above), or 
		// the freelist has no free block. chop one off from global pool (s_pNextBlock)
		// 		size is the actual alloc size (+block header)
        BUG_ON(pBucket->nSize == 0);
		pBlockHeader = (TBlockHeader *) s_pNextBlock;
		s_pNextBlock += (sizeof (TBlockHeader) + ulSize + BLOCK_ALIGN-1) & ~ALIGN_MASK; //xzl: round up?
		if (s_pNextBlock > s_pBlockLimit) {
            release(&alloc_lock);
			return 0;	    // no enough mem in reserved region for malloc()
		}
		pBlockHeader->nMagic = BLOCK_MAGIC;
		pBlockHeader->nSize = (unsigned) ulSize;	
	}

#ifdef MEM_DEBUG
    if (++pBucket->nCount > pBucket->nMaxCount)
        pBucket->nMaxCount = pBucket->nCount;
    // if (pBucket->nSize == 262144)
    //     I("xzl: origsize %lu pBucket->nSize %lu", origsize, pBucket->nSize);
#endif    
    release(&alloc_lock);

	pBlockHeader->pNext = 0;

	void *pResult = pBlockHeader->Data;
	assert (((unsigned long) pResult & ALIGN_MASK) == 0);

	return pResult;
}

void free (void *pBlock) {
	assert (pBlock != 0);
	TBlockHeader *pBlockHeader = (TBlockHeader *) ((unsigned long) pBlock - sizeof (TBlockHeader));
	assert (pBlockHeader->nMagic == BLOCK_MAGIC);
    BUG_ON(pBlockHeader->pNext != 0); // xzl this

    int freed = 0; 

	for (TBlockBucket *pBucket = s_BlockBucket; pBucket->nSize > 0; pBucket++) {
		if (pBlockHeader->nSize == pBucket->nSize) {
            acquire(&alloc_lock);
			pBlockHeader->pNext = pBucket->pFreeList;
			pBucket->pFreeList = pBlockHeader;
#ifdef MEM_DEBUG
			pBucket->nCount--;
#endif
        	release(&alloc_lock);
            freed = 1; 
			break;
		}
	}
    // not be able to find a freelist to return the given block, why?
    // W("pBlockHeader->nSize %u 0x%x", pBlockHeader->nSize, pBlockHeader->nSize); 
	BUG_ON(!freed);
}

#ifdef MEM_PAGE_ALLOC
void *palloc (void)
{
	assert (s_pNextPage != 0);

	EnterCritical ();

#ifdef MEM_DEBUG
	if (++s_PageBucket.nCount > s_PageBucket.nMaxCount)
	{
		s_PageBucket.nMaxCount = s_PageBucket.nCount;
	}
#endif

	TFreePage *pFreePage;
	if ((pFreePage = s_PageBucket.pFreeList) != 0)
	{
		assert (pFreePage->nMagic == FREEPAGE_MAGIC);
		s_PageBucket.pFreeList = pFreePage->pNext;
		pFreePage->nMagic = 0;
	}
	else
	{
		pFreePage = (TFreePage *) s_pNextPage;
		
		s_pNextPage += PAGE_SIZE;

		if (s_pNextPage > s_pPageLimit)
		{
			LeaveCritical ();

			return 0;		// TODO: system should panic here
		}
	}

	LeaveCritical ();
	
	return pFreePage;
}

void pfree (void *pPage) {
	assert (pPage != 0);
	TFreePage *pFreePage = (TFreePage *) pPage;
	
	EnterCritical ();

	pFreePage->nMagic = FREEPAGE_MAGIC;

	pFreePage->pNext = s_PageBucket.pFreeList;
	s_PageBucket.pFreeList = pFreePage;

#ifdef MEM_DEBUG
	s_PageBucket.nCount--;
#endif

	LeaveCritical ();
}
#endif

#ifdef MEM_DEBUG
void dump_mem_info (void) {
	for (TBlockBucket *pBucket = s_BlockBucket; pBucket->nSize > 0; pBucket++) {
		I("alloc: malloc(%u): outstanding %u blocks (max %u)",
			     pBucket->nSize, pBucket->nCount, pBucket->nMaxCount);
	}

#ifdef MEM_PAGE_ALLOC
	LoggerWrite (LoggerGet (), "alloc", LogDebug, "palloc: %u pages (max %u)",
		     s_PageBucket.nCount, s_PageBucket.nMaxCount);
#endif
}
#endif

