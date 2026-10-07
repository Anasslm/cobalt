ENTRY(_start)

PROVIDE(tohost   = 0x80001000);
PROVIDE(fromhost = 0x80001008);

MEMORY
{
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 64K
}

SECTIONS
{
    .text : ALIGN(4)
    {
        *(.text.init)
        *(.text.start)
        *(.text*)
    } > RAM

    .rodata : ALIGN(4)
    {
        *(.rodata*)
    } > RAM

    .data : ALIGN(8)
    {
        *(.data*)
    } > RAM

    .bss : ALIGN(8)
    {
        *(.bss*)
        *(COMMON)
    } > RAM
}