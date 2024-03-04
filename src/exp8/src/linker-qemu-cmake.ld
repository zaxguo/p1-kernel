SECTIONS
{
	. = 0xffff000040080000;
	.text.boot : { *(.text.boot) }
	. = ALIGN(0x00001000);
	user_begin = .;
	.text.user : { CMakeFiles/kernel8.elf.dir/src/user* (.text) }
	.rodata.user : { CMakeFiles/kernel8.elf.dir/src/user* (.rodata) }
	.data.user : { CMakeFiles/kernel8.elf.dir/src/user* (.data) }
	.bss.user : { CMakeFiles/kernel8.elf.dir/src/user* (.bss) }
	user_end = .;
	.text :  { *(.text) }
	.rodata : { *(.rodata) }
	.data : { *(.data) }
	. = ALIGN(0x8);
	bss_begin = .;
	.bss : { *(.bss*) } 
	bss_end = .;
	. = ALIGN(0x00001000);
	idmap_dir = .;
	.data.idmapd : {. += (3* (1 << 12));}
	. = ALIGN(0x00001000);
	pg_dir = .;
	.data.pgd : { . += (3 * (1 << 12)); }
}

