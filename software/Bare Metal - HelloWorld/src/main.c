#include <stdlib.h>
#include <stdio.h>
#include <harvsoc.h>
#include <csr.h>

int main() {

    set_harden_conf(0x37);

    uart_init(434, 0, 1); // 115200 baud rate
    printf("rstcause: 0x%X\n", rstcause_info());
    printf("implementation id: 0x%x\n", mimpid_info());

    printf("Hello world\n");

    return 0;
}
