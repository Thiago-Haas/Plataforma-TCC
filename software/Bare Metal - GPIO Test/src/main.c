#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <harvsoc.h>
#include <csr.h>

#ifndef IS_SIMULATION
#define DELAY_COUNT 100000
#else
#define DELAY_COUNT 100
#endif
int main() {
    set_harden_conf(0x37);
    uart_init(434, 0, 1); // 115200 baud rate
    printf("rstcause: %u\n", rstcause_info());
    printf("implementation id: 0x%x\n", mimpid_info());

    printf("GPIO test\n");

    while (1) {
        // delay
        for (int i = 0; i < DELAY_COUNT; i++) {
            wdt_feed();
        }

        // write 1 in first 4 leds
        printf("0\n");
        gpio_write(8, 1);
        gpio_write(7, 1);
        gpio_write(6, 1);
        gpio_write(5, 1);
        gpio_write(4, 0);
        gpio_write(3, 0);
        gpio_write(2, 0);
        gpio_write(1, 0);

        // read GPIO
        for (int i = 8; i >= 0; i--) {
            printf("[%d]: %x\n", i, gpio_read(i));
        }

        // delay
        for (int i = 0; i < DELAY_COUNT; i++) {
            wdt_feed();
        }

        // write 1 in last 4 leds
        printf("1\n");
        gpio_write(8, 0);
        gpio_write(7, 0);
        gpio_write(6, 0);
        gpio_write(5, 0);
        gpio_write(4, 1);
        gpio_write(3, 1);
        gpio_write(2, 1);
        gpio_write(1, 1);
        
        // read GPIO
        for (int i = 8; i >= 0; i--) {
            printf("[%d]: %x\n", i, gpio_read(i));
        }

#ifdef IS_SIMULATION
        break;
#endif

    }

    return 0;
}
