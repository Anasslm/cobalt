#include "cobalt.h"

int main(void)
{
    
    cobalt_printf("Hello Cobalt YAY!\n");

    cobalt_printf("Decimal: %d\n", -42);
    cobalt_printf("Unsigned: %u\n", 123);
    cobalt_printf("Hex: 0x%x\n", 0x1234);
    cobalt_printf("Character: %c\n", 'A');
    cobalt_printf("String: %s\n", "hello there");

    volatile uint64_t *sysctrl_chipid = (volatile uint64_t *)0x04000000;
    volatile uint64_t *sysctrl_tohost = (volatile uint64_t *)0x04000004;
    volatile uint64_t *sysctrl_fromhost = (volatile uint64_t *)0x04000008;

    cobalt_printf("sysctrl_chipid : %x\n", *sysctrl_chipid);
    
    cobalt_exit(0);

    while (1) {
    }

    return 0;
}