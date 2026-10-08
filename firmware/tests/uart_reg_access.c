#include "cobalt.h"
#include "uart.h"

extern void *__uart_base_addr__;

int main(void)
{
    volatile uint8_t *uart =
        (volatile uint8_t *)&__uart_base_addr__;

    uint8_t lsr;

    cobalt_printf("UART register access test\n");

    /*
     * Read Line Status Register
     */
    lsr = uart[UART_LINE_STATUS_REG_OFFSET];

    cobalt_printf("UART LSR = 0x%x\n", lsr);

    /*
     * Check transmitter status
     */
    if (!(lsr & (1 << UART_LINE_STATUS_THR_EMPTY_BIT))) {
        cobalt_printf("ERROR: THR is not empty\n");
        return 1;
    }

    if (!(lsr & (1 << UART_LINE_STATUS_TMIT_EMPTY_BIT))) {
        cobalt_printf("ERROR: transmitter is not empty\n");
        return 1;
    }

    /*
     * Write directly to THR
     */
    uart[UART_THR_REG_OFFSET] = 0x5;
    uart[UART_THR_REG_OFFSET] = 0xA;
    uart[UART_THR_REG_OFFSET] = 0x5;
    uart[UART_THR_REG_OFFSET] = 0xA;

    cobalt_printf("UART THR write completed\n");

    cobalt_printf("UART register access test PASSED\n");

    return 0;
}