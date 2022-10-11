#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <harvsoc.h>
#include <csr.h>

unsigned long trap_handler(
    unsigned long mepc,
    unsigned long mtval,
    unsigned long mcause,
    unsigned long mhartid,
    unsigned long mstatus,
    unsigned long sp
) {
    if (mcause >> 31) {
      // is interrupt
      printf("interrupt 0x%08X\n", mcause);
    } else {
      // is exception
      printf("exception 0x%08X\n", mcause);
    }
    return mepc;
}

int main() {
    set_harden_conf(0x37);
    uart_init(434, 0, 1); // 115200 baud rate
    printf("rstcause: %u\n", rstcause_info());
    printf("implementation id: 0x%x\n", mimpid_info());

    printf("GPIO test\n");

    while (1) {
        // delay
        for (int i = 0; i < 100000; i++)
            wdt_feed();
        gpio_write(8, 0);
        gpio_write(7, 0);
        gpio_write(6, 0);
        gpio_write(5, 0);
        gpio_write(4, 1);
        gpio_write(3, 1);
        gpio_write(2, 1);
        gpio_write(1, 1);
        for (int i = 8; i >= 0; i--)
            printf("[%d]: %x\n", i, gpio_read(i));
        // delay
        for (int i = 0; i < 100000; i++)
            wdt_feed();
        gpio_write(8, 1);
        gpio_write(7, 1);
        gpio_write(6, 1);
        gpio_write(5, 1);
        gpio_write(4, 0);
        gpio_write(3, 0);
        gpio_write(2, 0);
        gpio_write(1, 0);
        printf("1\n");
        for (int i = 8; i >= 0; i--)
            printf("[%d]: %x\n", i, gpio_read(i));
    }

    return 0;
}
