*2/24/2023: init draft by Zhiming Xu, TA of CS4414 Sp23.* 
*Edited on 2/25/2023*

During the rest of p1, we'll add the final piece of a modern OS to our kernel, virtual memory (VM). There are many new terms arising here that might overwhelm you. When I learned this part, I also felt perplexed by how elusively VM manifests itself. So, I'll try to provide a mental model of it step by step. Hopefully it'll help in your experiments.

---
### Welcome to the real world, where everything is where it appears
First, without VM, the addresses in our kernel are physical. Recall the address of `delay` you've seen in exp3, say, it's `0x82ef0`. Then if you read the kernel image byte by byte, it is located at `0x82ef0` bytes away from the beginning. In other words, it resides at that place, *physically*. Well, *Not exactly*. If you still remember, our kernel runs in a VM(=virtual machine). `QEMU` seizes the space until `0x80000`. So it's `2ef0` away, but if you're using the rpi3 hardware, what you see is undoubtfully physical. 
### NO! YOU SHALL NOT PASS
In reality, if everything is where it appears to be, the users can peek at the kernel and vice versa - we don't want that to happen. In order to separate the address spaces of user/kernel (as well as different tasks'), VM is invented to cover up the real addresses. In this way, every task is free to use any and all addresses they're entitled to (a user still can't trespass the kernel's territory), but now the addresses they claim are virtual. An address of `0x82ef0` doesn't necessarily locate at that # of bytes away from the beginning of the kernel image.
### Physical addresses and where to find them
However, the data stored at the `0x82ef0` still exist somewhere in the physical memory, and the kernel needs a way to know where to serve the task. At this step, we can think of a virtual memory address as a *pointer* in C that points to a memory object. Here are two print statements you can run. They demonstrate the relation between a pointer and the object it points to.
```
int a = 2023;
int *p = &a;
printf("%d", a); // this will give us 2023
printf("%ld", p); // this will give us the virtual memory address. still a number, but remotely likely to be 2023
```
The pointer `p` doesn't save the integer variable itself but contains the *address* of the place that stores `a`. Similarly, a VM address is not the place that physically stores a memory object, but a portal to that place.
#### A price to pay for the truth
So, how does the kernel translate a VM address to a physical one? Let's think of the translation process as a lookup table that encodes a one-to-one function, `f(VM)=PM`. An example is shown below.
```
| VM address | Physical address |
| -------- | ---------- |
| 0x80ef0  | 0x20230224 |
| 0x80ef1  | 0x20220224 |
| 0x80ef2  | 0x20210224 |
...
```
It's very nice that we can readily find the physical address with this table, but the problem is not solved yet. You might already notice that if a VM address can map to any physical address it desires, the table is REALLY huge. In Aarch64, the addresses are 8-byte(=64 bits) long, and there can be $2^{48}$ legitimate addresses. We only need one column because we index with the VM address (go `0x80ef0` bytes away from the beginning in the virtual world). If the mapping were arbitrary, we would need this # of rows, consuming $8\times 2^{48}$ bytes of memory. More than the entirety of the available VM, and MUCH MORE than the physical storage most of us can afford to buy!
### Spend less, get more
The next problem is thus, how to shrink this table and make it memory efficient. The concept of page, i.e., a 
*continuous* memory region of a fixed size, is introduced. Instead of per address, we mandate that a page in VM maps to a page in physical memory. In many platforms, we're dealing with a page size of 4KB($=2^{12}$). The policy ensures a 4KB region in VM gets translated to a 4KB region in physical memory. In this way, we only need to record the mapping between the beginning of this region in VM and the beginning of this region in PM, and keep only 1/4K entries in the table below.
```
| VM address | Physical address |
| -------- | ---------- |
| 0x80ef0  | 0x20230224 |
// all entries previously here no longer needed
| 0x80ef0+4K  | 0x20210224 |
...
```
With the introduction of *page*, how much space can we save? Previously, it's $8\times 2^{48}$. Now we only keep *one in a 4K*, 1/4K=$1/2^{12}$. It results in $8\times 2^{48}/2^{12}=8\times 2^{36}$, a triple-order magnitude reduction! You'll be promoted instantly if you can cut this much cost for your company.
### Still want to bargain?
We want to cut MORE! It's likely that we have enough money to buy a memory chip that can store the shrunk table, but human's greed knows no bounds. It drives us to build the final piece of VM, the hierarchy of page tables. Before, our translation has only one layer, i.e., `f(VM)=PM`, but what if hierarchical layers of them? 
Recall the pointer example above, we've shown a pointer that points to an integer. In fact, we can have a pointer that points to a pointer that points to an integer.
```
int a; int *p;
p = &a;
// p -> a: just one level
int a; int *p1; int **p2;
p1 = &a; p2 = &p1;
// p2 -> p1 -> a: two levels
```
We can of course add even more *a pointer that points to a pointer that points to...* in between to make the mechanism more obstructive/the sentence harder to read, but the example will do for the demonstration purpose.
### Take Me to Action, Boring Maths
In a standard Aarch64 VM layout with 4KB pages and additional four more hierarchies, i.e., PGD->PUD->PMD->PTE->pages. Apparently, one address of a higher hierarchy points to exactly *one table* (an array of the next-level pointers) of the immediately lower hierarchy. The information in each page table is 9-bit wide, totaling the full VM, $2^9\times2^9\times2^9\times2^9\times2^{12}=2^{48}$. In our experiment, it's a bit [simpler](https://fxlin.github.io/p1-kernel/exp6/rpi-os/#section-2mb-mapping). Since rpi3 only has 1GB physical memory, we can eliminate PTE and reduce the complexity. The smallest unit combines 9 bits in PTE and 12 bits in pages at 2MB$(=2^9\times 2^12)$. It's a *section* in Aarch64 term, but we'll conveniently call it a page. The tables in the experiment take their final form here.
```
PGD -> PUD -> PMD -> page
|    PGD   |      PUD      |        |    PUD   |      PMD      |        |    PMD   |    page   |
| -------- | ------------- |        | -------- | ------------- |        | -------- | --------- |
| pgd_addr | pud_addr[2^9] |        | pud_addr | pmd_addr[2^9] |        | pmd_addr | page[2^9] |
```
Even to the right of the three tables, each page represents 2MB memory. Now, how many tables do we need for the 1GB RAM of rpi3? First, there will be 1GB/2MB=$2^9$ pages. Since every `pmd_addr` points to an array of $2^9$ pages. We need exactly one `pmd_addr`. As the table shows above, each `pud_addr` points to $2^9$ `pmd_addr`, and each `pgd_addr` points to $2^9$ `pud_addr`. For the single `pmd_addr`, we still need one of `pud_addr` and `pgd_addr` respectively. In other words, we have exactly one table of {PGD, PUD, PMD}, and each table have exactly one entry. Follow the `int` pointer example above, we have
```
int pages[1<<9]; // 2^9 pages;
int *pmd[0];     // pmd is a single-element array, its element points to an int array
pmd[0] = pages;  // the entry is set to the beginning of the page array
int **pud[0];    // pud is a single-element array, its element points to {an array whose element points to an int array}
pud[0] = pmd;    // the entry is set to the beginning of the array that points to the page array
int ***pgd[0];   // pgd is a single-element array, its element points to {an array whose element points to (an array whose element points to an int array)}
pgd[0] = pud;
```
### Parting words
That's it! Now it's the journey's end of our VM tour. Your task in the following experiments is to fill in the tables so that we can command our VM space. And achieve the goal we have from the start - isolate user/kernel memory and *Confundo* every task to believe it owns the entirety of the memory space it's entitled to. Thank you for reading all the way down to this part, and hope you have a little bit more understanding of VM during this time.
