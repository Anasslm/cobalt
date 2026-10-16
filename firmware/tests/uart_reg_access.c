#include "cobalt.h"
#include "uart.h"

#define UART_CLK_FREQ 100000000ULL
#define UART_BAUD_RATE 115200ULL

extern void *__uart_base_addr__;

int main(void)
{
    void *uart = &__uart_base_addr__;

    cobalt_printf("UART register access test\n");

    // Configure UART using the SoC clock and desired baud rate.
    uart_init(uart, UART_CLK_FREQ, UART_BAUD_RATE);

    // Check that the transmitter is ready.
    uint8_t lsr =
        *(volatile uint8_t *)((uintptr_t)uart +
                              UART_LINE_STATUS_REG_OFFSET);

    cobalt_printf("UART LSR = 0x%x\n", lsr);

    if (!(lsr & (1u << UART_LINE_STATUS_THR_EMPTY_BIT))) {
        cobalt_printf("ERROR: THR is not empty\n");
        return 1;
    }

    cobalt_printf("Start uart sending\n");
    // Send known bytes through the UART.
    static const uint8_t msg[] = "K";
    uint8_t received;
    uart_write_str(uart, (void *)msg, sizeof(msg) - 1);
    uart_write_flush(uart);

    cobalt_printf("Waiting for UART loopback...\n");


    for (unsigned int i = 0; i < sizeof(msg) - 1; i++) {
        received = uart_read(uart);
    
        if (received != msg[i]) {
            cobalt_printf("UART RX FAIL at byte %u: expected %c, got %c\n",
                          i, msg[i], received);
            cobalt_exit(0);
        }
    }

    cobalt_printf("UART RX PASS: byte received correctly : %c\n", received);
    

    cobalt_printf("UART register access test PASSED\n");

    volatile uint64_t *sysctrl_chipid = (volatile uint64_t *)0x04000000;
    volatile uint64_t *sysctrl_tohost = (volatile uint64_t *)0x04000004;
    volatile uint64_t *sysctrl_fromhost = (volatile uint64_t *)0x04000008;

    cobalt_printf("sysctrl_chipid : %x\n", *sysctrl_chipid);
    cobalt_printf("sysctrl_tohost : %x\n", *sysctrl_tohost);
    cobalt_printf("sysctrl_fromhost : %x\n", *sysctrl_fromhost);

    cobalt_exit(0);
    return 0;

    return 0;
}