#include "cobalt.h"
#include "util.h"

#define CLINT_MTIMECMP ((volatile uint64_t *)0x02004000UL)
#define CLINT_MTIME    ((volatile uint64_t *)0x0200BFF8UL)
#define TIMER_TICKS    100

static volatile uint64_t timer_interrupt_count;

void machine_trap_handler(void)
{
    uint64_t cause;
    asm volatile("csrr %0, mcause" : "=r"(cause));

    if ((cause >> 63) && ((cause & 0xfff) == 7)) {
        *CLINT_MTIMECMP = *CLINT_MTIME + TIMER_TICKS;
        timer_interrupt_count++;
        return;
    }

    set_mie(0);
    set_mtie(0);
    for (;;) {
        asm volatile("wfi");
    }
}

int main(void)
{
    cobalt_printf("CLINT HELLO!\n");

    uint64_t start_time = *CLINT_MTIME;
    uint64_t deadline = start_time + TIMER_TICKS + 1000;
    *CLINT_MTIMECMP = start_time + TIMER_TICKS;
    set_mtie(1);
    set_mie(1);

    while (timer_interrupt_count < 5 && *CLINT_MTIME < deadline) {
        asm volatile("nop");
    }

    set_mie(0);
    set_mtie(0);

    if (timer_interrupt_count == 0) {
        cobalt_printf("ERROR: timer interrupt timed out\n");
        cobalt_exit(1);
        return 1;
    }

    cobalt_printf("Timer interrupt received: %d\n", (int)timer_interrupt_count);

    cobalt_exit(0);
    return 0;
}