#define K2_DEBUG_WARN 

#include "plat.h"
#include "utils.h"
#include "sched.h"
#include "mmu.h"
#include "elf.h"

// xzl: derived from xv6, for which user stack NOT at the very end of va
//  but next page boundary of user code (with 1 pg of stack guard
//  in between)   this limits to user stack to 4KB. (not growing)
//  (why designed like this??)
static int loadseg(struct mm_struct *mm, uint64 va, struct inode *ip, 
  uint offset, uint sz);

int flags2perm(int flags)
{
    // elf, https://refspecs.linuxbase.org/elf/gabi4+/ch5.pheader.html#p_flags
#define   PF_X    1
#define   PF_W    2
#define   PF_R    4

    int perm = 0;    
    BUG_ON(!(flags & PF_R));  // not readable? exec only??

    if(flags & PF_W)
      perm = MM_AP_RW;
    else 
      perm = MM_AP_EL0_RO; 

    if(!(flags & PF_X)) 
      perm |= MM_XN;

    return perm;
}


// we'll prepare a fresh pgtable tree "on the side", and allocates/
// maps new pages along the way. if everything
// works out, "swap" it with the existing pgtable tree. as a result,
// all existing user pages are freed and their mappings wont be 
// in the new pgtable tree. 
// 
// to implement this, we duplicate the task's mm, and clean all 
//  info for user pages; keep the info for kernel pages.
// in the end, we free all user pages (no need to unmap them).
//
// the caveat is, the pages backing the old pgtables are still kept
// in mm; they wont be free'd until the task exit()s. 
//

int
exec(char *path, char **argv)   // called from sys_exec
{
  char *s, *last;
  int i, off;
  uint64 argc, sz = 0, sz1, sp, ustack[MAXARG], argbase; 
  struct mm_struct *tmpmm = 0; 
  struct elfhdr elf;
  struct inode *ip;
  struct proghdr ph;
  void *kva; 
  struct task_struct *p = myproc();

  I("exec called. path %s", path);

  begin_op();

  if((ip = namei(path)) == 0){
    end_op();
    return -1;
  }
  ilock(ip);

  // Check ELF header
  if(readi(ip, 0, (uint64)&elf, 0, sizeof(elf)) != sizeof(elf))
    goto bad;

  if(elf.magic != ELF_MAGIC)
    goto bad;

  if(p->mm.pgd == 0)
    goto bad;

  _Static_assert(sizeof(struct mm_struct) <= PAGE_SIZE);  // otherwise, need more memory for mm....
  
  tmpmm = kalloc(); BUG_ON(!tmpmm); 
  // we will only remap user pages, so copy over kernel pages bookkeeping info
  //  the caveat is that some of the kernel pages (eg for the old pgtables) will become unused and will not be
  //  freed until exit()
  tmpmm->kernel_pages_count = p->mm.kernel_pages_count; 
  memcpy(&tmpmm->kernel_pages, &p->mm.kernel_pages, sizeof(tmpmm->kernel_pages)); 
  tmpmm->pgd = 0; // start from a fresh pgtable tree...

  // Load program into memory.  xzl: log segs assume seg vaddr are in ascending order...
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    if(readi(ip, 0, (uint64)&ph, off, sizeof(ph)) != sizeof(ph))
      goto bad;
    if(ph.type != ELF_PROG_LOAD)
      continue;
    // W("%lx %lx", ph.vaddr, sz);
    BUG_ON(ph.vaddr < sz); // sz: last seg's va end (exclusive)      
    if(ph.memsz < ph.filesz)
      goto bad;
      // xzl: TODO: load this seg only (vaddr,+memsz)
    // seg start must be page aligned, but end does not have to 
    if(ph.vaddr + ph.memsz < ph.vaddr)
      goto bad;
    if(ph.vaddr % PAGE_SIZE != 0) 
      goto bad;
    // if((sz1 = uvmalloc(pagetable, sz /*old*/, ph.vaddr + ph.memsz /*new*/, flags2perm(ph.flags))) == 0)
    //   goto bad;
    // sz = sz1;
    // xzl: TODO: also respect seg permission... flags2perm()
    for (sz1 = ph.vaddr; sz1 < ph.vaddr + ph.memsz; sz1 += PAGE_SIZE) {
      kva = allocate_user_page_mm(tmpmm, sz1, flags2perm(ph.flags)); 
      BUG_ON(!kva); 
    }
    sz = sz1; 
    if(loadseg(tmpmm, ph.vaddr, ip, ph.off, ph.filesz) < 0)
      goto bad;
  }
  iunlockput(ip);
  end_op();
  ip = 0;
  
  sz = PGROUNDUP(sz);  
  
  // User stack 
  assert(sz + PAGE_SIZE + USER_MAX_STACK <= USER_VA_END); 
  // alloc the 1st stack page (instead of demand paging), for pushing args (below)
  if (!(kva=allocate_user_page_mm(tmpmm, USER_VA_END - PAGE_SIZE, MMU_PTE_FLAGS | MM_AP_RW))) {
    BUG(); 
    goto bad; 
  }
  memzero(kva, PAGE_SIZE); 
  // map a guard page near USER_MAX_STACK as non accessible
  if (!(kva=allocate_user_page_mm(tmpmm, USER_VA_END - USER_MAX_STACK - PAGE_SIZE, MMU_PTE_FLAGS | MM_AP_EL1_RW))) {
    BUG(); 
    goto bad; 
  }

  sp = USER_VA_END; 
  argbase = USER_VA_END - PAGE_SIZE; // args at most 1 PAGE
  // Push argument strings, prepare rest of stack in ustack.
  // Populate arg strings on stack. save arg pointers to ustack (a scratch buf)
  //    then populate "ustack" on the stack
  for(argc = 0; argv[argc]; argc++) {
    if(argc >= MAXARG)
      goto bad;
    sp -= strlen(argv[argc]) + 1;
    sp -= sp % 16; // riscv sp must be 16-byte aligned  xzl: do we need this?
    if(sp < argbase)
      goto bad;
    if(copyout(tmpmm, sp, argv[argc], strlen(argv[argc]) + 1) < 0)
      goto bad;
    ustack[argc] = sp;
  }
  ustack[argc] = 0; // last arg

  // push the array of argv[] pointers.
  sp -= (argc+1) * sizeof(uint64);
  sp -= sp % 16;  // xzl: do we need this
  if(sp < argbase)
    goto bad;
  if(copyout(tmpmm, sp, (char *)ustack, (argc+1)*sizeof(uint64)) < 0)
    goto bad;

  // arguments to user main(argc, argv)
  // argc is returned via the system call return
  // value, which goes in a0.
  struct pt_regs *regs = task_pt_regs(p);
  regs->regs[1] = sp; 

  // Save program name for debugging.
  for(last=s=path; *s; s++)
    if(*s == '/')
      last = s+1;
  safestrcpy(p->name, last, sizeof(p->name));
    
  // Commit to the user image. free previous user mapping, pages. if any
  regs->pc = elf.entry;  // initial program counter = main
  regs->sp = sp; // initial stack pointer
  V("init sp 0x%lx", sp);
  free_task_pages(&p->mm, 1 /*useronly*/); 
  p->mm = *tmpmm; 
  p->mm.sz = p->mm.codesz = sz; 
  kfree(tmpmm); 

  set_pgd(p->mm.pgd);

  V("exec succeeds argc=%ld", argc);
  return argc; // this ends up in x0, the first argument to main(argc, argv)

 bad:
  if(tmpmm && tmpmm->pgd) { // new pgtable tree ever allocated .. 
    free_task_pages(tmpmm, 1 /*useronly*/);    
  }
  if (tmpmm)
    kfree(tmpmm); 
  if(ip){
    iunlockput(ip);
    end_op();
  }
  I("exec failed");
  return -1;
}

// Load a program segment into pagetable at virtual address va.
// va must be page-aligned
// and the pages from va to va+sz must already be mapped.
// Returns 0 on success, -1 on failure.
static int
loadseg(struct mm_struct* mm, uint64 va, struct inode *ip, uint offset, uint sz)
{
  uint i, n;
  uint64 pa;

  assert(va % PAGE_SIZE == 0); 
  assert(mm);

  // Verify mapping page by page, then load from file
  for(i = 0; i < sz; i += PAGE_SIZE){
    pa = walkaddr(mm, va + i);
    if(pa == 0)
      panic("loadseg: address should exist");
    if(sz - i < PAGE_SIZE)
      n = sz - i;
    else
      n = PAGE_SIZE;
    if(readi(ip, 0/*to kernel va*/, (uint64)PA2VA(pa), offset+i, n) != n)
      return -1;
  }
  
  return 0;
}

