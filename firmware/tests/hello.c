#include "cobalt.h"

int main(void)
{
    
    cobalt_printf("Hello Cobalt YAY!\n");

    cobalt_printf("Decimal: %d\n", -42);
    cobalt_printf("Unsigned: %u\n", 123);
    cobalt_printf("Hex: 0x%x\n", 0x1234);
    cobalt_printf("Character: %c\n", 'A');
    cobalt_printf("String: %s\n", "hello there");

    volatile uint32_t *dma_base = (volatile uint32_t *) 0x10000000;

    *dma_base = 0xdeadbeed;
    
    cobalt_exit(0);

    while (1) {
    }

    return 0;
}