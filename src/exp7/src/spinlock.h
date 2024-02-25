// Mutual exclusion lock.
// derived from xv6

struct spinlock {
  unsigned int locked;       // Is the lock held?

  // For debugging:
  char *name;        // Name of lock.
  struct cpu *cpu;   // The cpu holding the lock. // we only assume 1 cpu core
};

