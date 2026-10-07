#ifndef COBALT_H
#define COBALT_H

#include <stdint.h>

#define TOHOST_ADDR        0x80001000UL
#define TOHOST_MAGIC       0x434F4241ULL
#define TOHOST_CMD_PUTCHAR 0x01UL
#define TOHOST_CMD_EXIT    0xFFUL

static inline void cobalt_putchar(char c)
{
    volatile uint64_t *tohost =
        (volatile uint64_t *)TOHOST_ADDR;

    uint64_t msg =
        ((uint64_t)TOHOST_MAGIC << 32) |
        ((uint64_t)TOHOST_CMD_PUTCHAR << 24) |
        (uint8_t)c;

    *tohost = msg;
}

static inline void cobalt_exit(uint16_t code)
{
    volatile uint64_t *tohost =
        (volatile uint64_t *)TOHOST_ADDR;

    uint64_t msg =
        ((uint64_t)TOHOST_MAGIC << 32) |
        ((uint64_t)TOHOST_CMD_EXIT << 24) |
        code;

    *tohost = msg;
}

void cobalt_printf(const char *format, ...);

#endif