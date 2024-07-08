// #include <klib.h>
// #include <klib-macros.h>
// #include <sys/types.h>
#include <sys/wait.h>
#include "stdio.h"
#include "stdlib.h"
#include "string.h"
#include "assert.h"

#include "vos.h"
#include "Block.h"
#include "sha256.h"

// "sDataIn": string to add a bit randomness to hash input string
void Block::block_init(uint32_t nIndexIn, const char *sDataIn, const char *sPrevHashIn) {
    _nIndex = nIndexIn;
    _sData = sDataIn;
    _sPrevHash = sPrevHashIn;
    _nNonce = -1;
    _tTime = uptime_ms()/1000;
}

const char *Block::GetHash() {
    return _sHash;
}

// search for a nouce value, so that the computed hash (as string) matches
// "diffStr"
void Block::MineBlock(const char *diffStr) {
    int nDifficulty = strlen(diffStr);
    do {
        _nNonce++;
        _CalculateHash(_sHash);
    } while (memcmp(_sHash, diffStr, nDifficulty) != 0);

    printf("Block mined:%s\n", _sHash);
}

////// SMP version 

#define NWORKERS 4
// #define NWORKERS 1

struct miner_param {
	Block *context; 
	int taskid; 
	// unsigned nounce; 
	const char *diffstr; 
	int found; 
	// char *resHash; // copy results to 
};

// threading version 
// buf: working buffer; also contains the final output
// str: string working buffer, at least 1024; len: its length 
void Block::_CalculateHash_r(Block *blk, 
	char *buf, char *str, int nounce) {
	// str: input to hash, with added randomness (e.g. time) & prev hash
    sprintf(str, "%d%d%s%d%s", 
		blk->_nIndex, blk->_tTime, blk->_sData, 
		nounce, blk->_sPrevHash);
	// hash twice
    sha256(buf, str);
    sha256(buf, buf);
}

#define HASHLEN (2 * SHA256::DIGEST_SIZE + 1)
#define STRLEN 1024

extern void printf_r(const char *fmt,...);  // main.cpp. doea not work 
extern int sem_print; // main.cpp 

#define PRINTF_R(fmt, arg...) \
	do {	sys_semp(sem_print);	\
			printf(fmt, ## arg);	\
			sys_semv(sem_print);	\
	} while (0)

int Block::miner0(void *param) {	
	struct miner_param *p = (struct miner_param *)param; 
	Block *blk = p->context; 
	int diff = strlen(p->diffstr); 
	int found; 

	int tid = __atomic_fetch_add(&p->taskid,1,__ATOMIC_SEQ_CST); assert(tid<NWORKERS); 

	// sys_semp(sem_print); // printf_r() didn't work. cf its comment. TBD
	PRINTF_R("child tid %d: p addr %lx p->tid %d found %d mytid %d\n", tid,
		(unsigned long)p, p->taskid, p->found, tid);
	// sys_semv(sem_print);

	return 0; 
}

int Block::miner(void *param) {	
	struct miner_param *p = (struct miner_param *)param; 
	Block *blk = p->context; 
	char *myhash = (char*)malloc(HASHLEN); assert(myhash); // thread-local buf
	char *mystr = (char*)malloc(STRLEN); assert(mystr); 
	int diff = strlen(p->diffstr); 
	int found; 

	int tid = __atomic_fetch_add(&p->taskid,1,__ATOMIC_SEQ_CST); assert(tid<NWORKERS); 
	printf_r("task %d alive\n", tid); 
	// printf("task %d alive\n", tid); 

	do {
		if (__atomic_load_n(&p->found, __ATOMIC_SEQ_CST) == 1)
			goto out; 
		unsigned nounce = __atomic_add_fetch(&blk->_nNonce,1,__ATOMIC_SEQ_CST); 
		_CalculateHash_r(blk, myhash, mystr, nounce); 
	} while (memcmp(myhash, p->diffstr, diff));

	found = 0; 
	if (__atomic_compare_exchange_n(&p->found, &found, 1, 
		false, __ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST)) {
		memcpy(blk->_sHash, myhash, HASHLEN); 
	}
out:
	free(myhash); free(mystr); 
	return 0; 
}

// Be careful with THREAD_STACK_SIZE --> If too small, stacks may corrupt;
// threads will throw erratic bugs like memory faults at strange addresses
#define THREAD_STACK_SIZE 4096
char stacks[NWORKERS*THREAD_STACK_SIZE]; 
// This is ok -- an abitrary VA in the middle of user VM. kernel will alloc
// stack on demand. Only problem is that do_mem_abort() in the kernel has to be 
// less sensitive about repeated pgfaults (TBD
// char * stacks = (char *)(64 * 1024 *1024); 

void Block::MineBlockSMP(const char *diffstr) {
	struct miner_param p = {
		.context = this, 
		.taskid = 0,
		.diffstr = diffstr,
		.found = 0,
	};
	// p.taskid = 0; 
	// p.nounce = _nNonce; 
	// p.diff = 
    // int nDifficulty = strlen(diffStr);

	int pid, n; 
	printf("parent: p addr %lx\n", (unsigned long)&p);
	for(n=0; n<NWORKERS; n++){
    	pid = clone(Block::miner0, stacks+(n+1)*THREAD_STACK_SIZE, CLONE_VM, &p);		
    	assert(pid>0); 
  	}
	for(; n > 0; n--){
		if(wait(0) < 0)	{
			printf("%s: wait stopped early\n", __func__);
			exit(1);
		}
	}
	printf("wait done\n");
	_sHash[0]='\0';
    printf("Block mined:%s\n", _sHash);
}

// buf: working buffer; also contains the final output
inline void Block::_CalculateHash(char *buf) {
    static char str[1024];
	// str: input to hash, with added randomness (e.g. time) & prev hash
    sprintf(str, "%d%d%s%d%s", _nIndex, _tTime, _sData, _nNonce, _sPrevHash);
	// hash twice
    sha256(buf, str);
    sha256(buf, buf);
}
