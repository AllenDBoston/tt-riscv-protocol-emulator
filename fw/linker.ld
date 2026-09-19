MEMORY
{
    ROM  (rx)  : ORIGIN = 0x00000000, LENGTH = 2K
    SRAM (rwx) : ORIGIN = 0x20000000, LENGTH = 1K
}

SECTIONS
{
    .text : {
        *(.init)
        *(.text*)
        *(.rodata*)
    } > ROM

    .data : {
        *(.data*)
        *(.sdata*)
    } > SRAM AT > ROM

    .bss : {
        __bss_start = .;
        *(.bss*)
        *(.sbss*)
        __bss_end = .;
    } > SRAM

    /* Define Stack top at the end of 1KB SRAM */
    __stack_top = ORIGIN(SRAM) + LENGTH(SRAM);
}
