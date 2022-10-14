OUTPUT_ARCH(riscv)

/* required to correctly link newlib */
GROUP( -lc -lgloss -lgcc -lsupc++ )

RAM_BASE_ADDR = 0x70000000;
RAM_HIGH_ADDR = DEFINED(RAM_HIGH_ADDR) ? RAM_HIGH_ADDR : 0x70007FFF;

RAM_SIZE = RAM_HIGH_ADDR - RAM_BASE_ADDR + 1;
STACK_SIZE = RAM_SIZE / 16;

MEMORY
{
  ram (rwx) : ORIGIN = RAM_BASE_ADDR, LENGTH = RAM_SIZE
}

ENTRY(_start)


SECTIONS
{
  .init :
  {
    __init_start = . ;
    . = ALIGN(8);
    *(.init*)
  } > ram

  .text :
  {
    *(.text*)
    KEEP(*(.vector*))
  } > ram

  /* DATA MEMORY */

  __lma_ram_start = . ;

  .preinit_array :
  {
    __vma_ram_start = . ;
    PROVIDE_HIDDEN (__preinit_array_start = . );
    KEEP (*(.preinit_array))
    PROVIDE_HIDDEN (__preinit_array_end = . );
  } > ram

  .init_array :
  {
    PROVIDE_HIDDEN (__init_array_start = . );
    KEEP (*(SORT(.init_array.*)))
    KEEP (*(.init_array ))
    PROVIDE_HIDDEN (__init_array_end = . );
  } > ram

  .fini_array :
  {
    PROVIDE_HIDDEN (__fini_array_start = . );
    KEEP (*(SORT(.fini_array.*)))
    KEEP (*(.fini_array ))
    PROVIDE_HIDDEN (__fini_array_end = . );
  } > ram

  .rodata :
  {
    _start_rodata = . ;
    *(.rodata*)
    *(.rodata.*)
    *(.srodata.*)
    _end_rodata = . ;
  } > ram

  .eh_frame :
  {
    . = ALIGN(4);
    *(.eh_frame*)
  } > ram

  .data.impure_data :
  {
    . = ALIGN(4);
    *(.data.impure_data)
  } > ram

  .data :
  {
	*(.data .data.*)
	*(.gnu.linkonce.d.*)
  . = ALIGN(4) ;
  _start_data = . ;
  *(.sdata .sdata.*)
  *(.sdata2 .sdata2.*)
	*(.gnu.linkonce.s.*)
	*(.srodata .srodata.*)
    _edata = . ;
  } > ram

  .custom.crc :
  {
    __app_crc  = . + 4; /* This value will be replaced with actual crc in next ahx */
  } > ram

  .bss (NOLOAD) :
  {
    . = ALIGN(4);
    _bss_lma = . ;

    *(.bss .bss.*)
    *(.sbss .sbss.*)
    *(.shbss .shbss.*)
    *(COMMON)
    _ebss = . ;

    . = ALIGN(4);

    __global_pointer = . + 0x800;

  } > ram

  .stack (NOLOAD) :
  {
    . = ALIGN(4);
    _stack_lma = . ;
    . = . + STACK_SIZE - 4;
    _estack = . ;
  } > ram

  . = . + 4;
  _heap_lma = . ;

  /DISCARD/ :
  {
    *(.riscv.*)
    *(.comment)
    *(.debug_*)
  }

}
