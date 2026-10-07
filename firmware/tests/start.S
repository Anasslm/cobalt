.section .text.start
.global _start
.type _start, @function

_start:
    # Initialize stack pointer
    li   sp, 0x80010000

    # Call C main()
    call main

1:
    j    1b