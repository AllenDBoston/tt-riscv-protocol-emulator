.section .init
.global _start

_start:
    /* Initialize stack pointer */
    li sp, 0x20000100 /* 0x20000000 + 256 */

    /* Clear BSS */
    la a0, __bss_start
    la a1, __bss_end
    bgeu a0, a1, 2f
1:
    sw zero, 0(a0)
    addi a0, a0, 4
    bltu a0, a1, 1b
2:
    /* Call main */
    call main

    /* Infinite loop if main returns */
3:
    j 3b
