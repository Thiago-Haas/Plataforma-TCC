#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <harvsoc.h>
#include <csr.h>

extern void _putchar(char);
extern int _write(int, char*, int);
extern void _write_hex(unsigned long, int);

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
      _write(1, "interrupt 0x", 12);
      _write_hex(mcause, 8);
      _putchar('\n');
    } else {
      // is exception
      _write(1, "except 0x", 9);
      _write_hex(mcause, 8);
      _putchar('\n');
    }
    
    return mepc;
}

int main() {

    set_harden_conf(0x37);

    uart_init(434, 0, 1); // 115200 baud rate
    printf("rstcause: 0x%X\n", rstcause_info());
    printf("implementation id: 0x%x\n", mimpid_info());

    printf("Hello world\n");

    return 0;
}
