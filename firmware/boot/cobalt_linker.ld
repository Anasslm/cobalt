ENTRY(_start)

/* Define symbols for host communication */
PROVIDE(tohost   = 0x80001000);
PROVIDE(fromhost = 0x80001008); /* Optional, if we need host->target communication */

MEMORY
{
    ROM (rx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
    .text : ALIGN(4)
    {
        *(.text.boot)
        *(.text*)
    } > ROM
}