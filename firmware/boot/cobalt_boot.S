_start:
    # RAM entry address
    li   t0, 0x80000000

    # Hart ID
    csrr a0, mhartid

    # Jump to RAM
    jr   t0

1:
    j 1b