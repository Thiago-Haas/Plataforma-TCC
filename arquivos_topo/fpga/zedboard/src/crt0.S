# CSR addresses
.equ CSR_RSTCAUSE_ADDR,    0x7C0
.equ CSR_HARDEN_CONF_ADDR, 0x7C1
# peripherals addresses
.equ UART_INTERFACE_ADDR, 0x80000000 # UART base address in AMBA bus
.equ UART_BAUD_REG_ADDR,  0x80000004
.equ UART_PARITY_ADDR,    0x80000008
.equ UART_RTSCTS_ADDR,    0x8000000C
.equ UART_STATUS_ADDR,    0x80000010
.equ WDT_ADDR,            0x80000100 # WDT base address in AMBA bus
.equ GPIO_BASE_ADDR,      0x80000204 # GPIO pins address in AMBA bus
# event handler addresses
.equ EH_EVENT_ID,          0x01000000
.equ EH_PC,                0x01000004
.equ EH_INSTR,             0x01000008
.equ EH_ENC_DATA,          0x0100000C
.equ EH_ENC_DATA_ECC,      0x01000010
.equ EH_ALU_RESULT,        0x01000014
.equ EH_MCYCLE,            0x01000018
.equ EH_MCYCLEH,           0x0100001C
.equ EH_JALLOG_PTR,        0x01000020
.equ EH_JALLOG_SIZE,       0x01000024
.equ EH_JALLOG_BASE,       0x01000800
.equ MEM_EH_EVENT_ID,      0x70800000
.equ MEM_EH_MEM_ADDR,      0x70800004
.equ MEM_EH_MEM_ECC_ADDR,  0x70800014
.equ MEM_EH_ENC_DATA,      0x70800008
.equ MEM_EH_ENC_DATA_ECC,  0x7080000C
.equ MEM_EH_MEM_PREV_ADDR, 0x70800018
.equ MEM_EH_ENABLE,        0x70800010
.section .rodata
start_msg:  .asciz "START\n"

.section .data
.global harvsoc_rstcause
harvsoc_rstcause: .word 0x0

.section .init, "ax"
.global _start
_start:
    .cfi_startproc
    .option push
    .option norelax
    .cfi_undefined ra

    .option pop

    la       sp, _estack                 # initialize stack with last address of stack
    la       gp, __global_pointer        # set global pointer register
    mv       x1, zero
    mv       x4, zero
    mv       x5, zero
    mv       x6, zero
    mv       x7, zero
    mv       x8, zero
    mv       x9, zero
    mv      x10, zero
    mv      x11, zero
    mv      x12, zero
    mv      x13, zero
    mv      x14, zero
    mv      x15, zero
    mv      x16, zero
    mv      x17, zero
    mv      x18, zero
    mv      x19, zero
    mv      x20, zero
    mv      x21, zero
    mv      x22, zero
    mv      x23, zero
    mv      x24, zero
    mv      x25, zero
    mv      x26, zero
    mv      x27, zero
    mv      x28, zero
    mv      x29, zero
    mv      x30, zero
    mv      x31, zero

    /* initialize UART baud rate */
    li      s0, UART_BAUD_REG_ADDR   # set UART baud rate div register address
    li      a0, 434                  # set baud rate div for 115200 baud rate
    sw      a0, 0(s0)                # set value of baud rate div register

    li      s0, UART_PARITY_ADDR     # set UART parity register address
    li      a0, 0                    # set parity none
    sw      a0, 0(s0)                # set value of uart parity register

    li      s0, UART_RTSCTS_ADDR     # set UART RTSCTS enable register address
    li      a0, 1                    # set rtscts flow control true
    sw      a0, 0(s0)                # set value of rtscts flow control register

init_uart:
    li      s0, UART_INTERFACE_ADDR
    li      t0, 0x0A
    sb      t0, 0(s0)
    li      t2, 1

init_wait_uart:
    li      s0, UART_STATUS_ADDR
    lw      t1, 0(s0)
    srl     t1, t1, 1
    and     t1, t1, 1
    beq     t1, t2, init_wait_uart

    /* Initialize GPIO pins as zero  */
    li      s0, GPIO_BASE_ADDR
    sw      zero, 0(s0)

    # /* disable memory event handler */
    # li      s0, MEM_EH_ADDR
    # sw      x0, 16(s0)

# #ifndef IS_SIMULATION
#     /* initialize memory */
# init_mem:
#     la      s0, RAM_BASE_ADDR           # get first ram address from linker
#     la      s1, RAM_HIGH_ADDR           # get last ram address from linker
# init_mem_loop:
#     sw      zero, 0(s0)                 # init with zero
#     addi    s0, s0, 4                   # increment address
#     bleu    s0, s1, init_mem_loop       # branch to loop while does not reach s0
# #endif

enable_seh:
    # /* enable memory event handler */
    # li      s0, MEM_EH_ADDR
    # li      t0, 1
    # sw      t0, 16(s0)

    /* initialize CSRs */
#ifdef APP_TRAP_ENTRY
    #if (APP_TRAP_ENTRY != 1)
        la     a0, APP_TRAP_ENTRY    # get APP_TRAP_ENTRY function address
        csrw   mtvec, a0             # set MTVEC
    #endif
#else
    la      a0, _trap_entry           # get address of default trap entry
    csrw    mtvec, a0                 # set MTVEC
#endif
    csrw    mstatus, zero
    csrw    mie, zero                 # clear mie (interruptions)

    /* initialize reset cause */
    la      s0, harvsoc_rstcause      # load reset cause variable address
    csrr    a0, CSR_RSTCAUSE_ADDR     # read reset cause from CSR
    sw      a0, 0(s0)                 # set reset cause global variable
    csrw    CSR_RSTCAUSE_ADDR, zero   # clear reset cause CSR

// definition for experiment that cycles when a reset has happened
#ifdef CYCLING_EXPERIMENT
cycle_hardening:
    /* cycle error correction */
    la      s0, harvsoc_rstcause         # load rstcause variable address
    lw      s0, 0(s0)                    # read reset cause
    csrr    s1, CSR_HARDEN_CONF_ADDR     # read hardening configuration
    li      t0, 0x2                      # t0 = 2
    beq     s0, t0, cycle_set_conf       # if reset cause is wdt reset, cycle configuration
    j       set_hardened                 # _else set hardened
cycle_set_conf:
    li      t0, 0x37                     # load hardened configuration
    beq     s1, t0, set_unhardened       # if it is hardened, branch to unhardened
set_hardened:                            # _else set hardened
    li      t0, 0x37                     # set fully hardened conf
    csrw    CSR_HARDEN_CONF_ADDR, t0     # write CSR
    j       continue
set_unhardened:
    li      t0, 0x04                     # set unhardened conf (only memory ECC)
    csrw    CSR_HARDEN_CONF_ADDR, t0     # write CSR
continue:
#else
    #ifdef HARV_CONFIG
        li      t0, HARV_CONFIG      # set fully parameterized configuration
    #else
        li      t0, 0x37             # set fully hardened conf
    #endif
    csrw    CSR_HARDEN_CONF_ADDR, t0 # set hardening CSR
#endif

    /* print INIT */
    li      a0, 0x49
    call    asm_putchar
    li      a0, 0x4e
    call    asm_putchar
    li      a0, 0x49
    call    asm_putchar
    li      a0, 0x54
    call    asm_putchar
    li      a0, 0xA
    call    asm_putchar
    # print reset cause as hex
    la      a0, harvsoc_rstcause         # load rstcause variable address
    lw      a0, 0(a0)                    # read reset cause
    li      a1, 8
    call    asm_write_hex
    # print hardening configuration as hex
    csrr    a0, CSR_HARDEN_CONF_ADDR
    li      a1, 8
    call    asm_write_hex

    /* copy contents from NVM to RAM */
#     la      s8,  __lma_ram_start        # get start load address to load from NVM
#     la      s10, __vma_ram_start        # get start virtual address to load to RAM
#     la      s11, __vma_ram_end          # get end virtual address to load to RAM
#     bgeu    s10, s11, init_ram_end      # dont go into loop if it has no RAM
# init_ram_loop:
#     lw      t1,  0(s8)                  # load from LMA
#     sw      t1,  0(s10)                 # save to VMA

#     addi    s8,  s8,  4                 # increment 4
#     addi    s10, s10, 4                 # increment 4
#     bltu    s10, s11, init_ram_loop     # branch if not finished
# init_ram_end:

#     /* clear BSS */
#     la      s10, _bss_lma               # bss start
#     la      s11, _ebss                  # bss end
#     bgeu    s10, s11, clear_bss_end     # dont go into loop if it has no bss
# clear_bss_loop:
#     sw      x0, 0(s10)                  # set 0 in bss address
#     addi    s10, s10, 4                 # increment 4
#     bleu    s10, s11, clear_bss_loop    # branch if not finished
# clear_bss_end:

#ifndef NO_STDLIB
    /* run global initialization functions */
    call    __libc_init_array

    /* print start message */
    la      a0, start_msg               # load address with START message
    call    printf                      # call printf function
#endif

    /* jump to main program entry point (argc = argv = envp = 0) */
    li      a0, 0
    li      a1, 0
    li      a2, 0
    call    main

    /* if program exits call exit routine */
    call    exit

    .cfi_endproc

/*** TRAP HANDLER ***/
#ifndef APP_TRAP_ENTRY
.altmacro
.align 4
.macro SAVE_CONTEXT
    addi sp, sp, -32*4
    .set i, 1
    .rept 31
          save_gp %i
          .set i, i+1
    .endr
.endm
.macro save_gp i, basereg=sp
    sw x\i, ((\i)*4)(\basereg)
.endm
.align 4
.macro RESTORE_CONTEXT
    .set i, 1
    .rept 31
          load_gp %i
          .set i, i+1
    .endr
    addi sp, sp, 32*4
.endm
.macro load_gp i, basereg=sp
    lw x\i, ((\i)*4)(\basereg)
.endm

_trap_entry:
    SAVE_CONTEXT

    /* check if it is ecall or interruption to skip event printing  */
    csrr    a0, mcause                       # read trap cause CSR
    li      a1, 0x0000000B                   # load ecall trap cause value
    beq     a0, a1, handle_trap              # branch if trap is ecall
    srl     a0, a0, 31                       # get most significant bit of data
    bne     a0, x0, handle_trap              # branch if trap is interrupt

    /* print TRAP */
    li      a0, 0x0A
    call    asm_putchar
    li      a0, 0x54
    call    asm_putchar
    li      a0, 0x52
    call    asm_putchar
    li      a0, 0x41
    call    asm_putchar
    li      a0, 0x50
    call    asm_putchar
    li      a0, 0x0A
    call    asm_putchar

    csrr    a0, CSR_HARDEN_CONF_ADDR
    li      a1, 8
    call    asm_write_hex

    csrr    a0, mepc
    li      a1, 8
    call    asm_write_hex

    csrr    a0, mcause
    li      a1, 8
    call    asm_write_hex

    # PRINT EVENT INFORMATION
    li      a0, EH_EVENT_ID
    lw      a0, 0(a0)
    li      a1, 4
    call    asm_write_hex
    
    li      a0, EH_PC
    lw      a0, 0(a0)
    li      a1, 8
    call    asm_write_hex

    li      a0, EH_INSTR
    lw      a0, 0(a0)
    li      a1, 8
    call    asm_write_hex

    li      a0, EH_ENC_DATA
    lw      a0, 0(a0)
    li      a1, 8
    call    asm_write_hex

    li      a0, EH_ENC_DATA_ECC
    lw      a0, 0(a0)
    li      a1, 2
    call    asm_write_hex

    li      a0, EH_ALU_RESULT
    lw      a0, 0(a0)
    li      a1, 8
    call    asm_write_hex

    li      a0, EH_MCYCLE
    lw      a0, 0(a0)
    li      a1, 8
    call    asm_write_hex

    li      a0, EH_MCYCLEH
    lw      a0, 0(a0)
    li      a1, 8
    call    asm_write_hex

    li      a0, EH_JALLOG_PTR
    lw      a0, 0(a0)
    li      a1, 3
    call    asm_write_hex

    li      a0, EH_JALLOG_SIZE
    lw      a0, 0(a0)
    mv      s1, a0
    li      a1, 3
    call    asm_write_hex

    li      s0, EH_JALLOG_BASE   # load JALLOG base address to s0
    sll     s1, s1, 2            # multiply jallog size by 4
    add     s1, s0, s1           # get high address
loop_jallog:
    lw      a0, 0(s0)            # read JALLOG data
    li      a1, 8                # set number of digits to print
    call    asm_write_hex        # call hex write print
    addi    s0, s0, 4            # increment JALLOG pointer to data
    bltu    s0, s1, loop_jallog  # if it's not last address, loop

    ## MEM event handler

#     li      a0, MEM_EH_EVENT_ID
#     lw      a0, 0(a0)
#     li      a1, 1
#     call    asm_write_hex

#     li      a0, MEM_EH_MEM_ADDR
#     lw      a0, 0(a0)
#     li      a1, 8
#     call    asm_write_hex

#     li      a0, MEM_EH_MEM_ECC_ADDR
#     lw      a0, 0(a0)
#     li      a1, 8
#     call    asm_write_hex

#     li      a0, MEM_EH_ENC_DATA
#     lw      a0, 0(a0)
#     li      a1, 8
#     call    asm_write_hex

#     li      a0, MEM_EH_ENC_DATA_ECC
#     lw      a0, 0(a0)
#     li      a1, 2
#     call    asm_write_hex

#     li      a0, MEM_EH_MEM_PREV_ADDR
#     lw      a0, 0(a0)
#     li      a1, 8
#     call    asm_write_hex

#     li      a0, MEM_EH_ENABLE
#     lw      a0, 0(a0)
#     li      a1, 1
#     call    asm_write_hex

#     /* error correction of memory events */
#     li      a0, MEM_EH_EVENT_ID              # load event id address
#     lw      a0, 0(a0)                        # read memory event id
#     beq     a0, x0, skip_correction          # if there are no memory events, skips correction
#     li      s0, MEM_EH_MEM_ADDR              # load address of error address
#     lw      s0, 0(s0)                        # read error address
#     la      t0, RAM_BASE_ADDR                # load memory base address
#     add     s0, s0, t0                       # increment with base RAM address
#     lw      s1, 0(s0)                        # read data with error
#     sw      s1, 0(s0)                        # write data back to memory to remove the ecc error
# skip_correction:

handle_trap:
#ifdef APP_TRAP_HANDLER
    # load TRAP data from CSRs
    csrr    a0, mepc                         # read mepc to argument 0
    csrr    a1, mtval                        # read mtval to argument 1
    csrr    a2, mcause                       # read mcause to argument 2
    csrr    a3, mhartid                      # read mhardid to argument 3
    csrr    a4, mstatus                      # read mstatus to argument 4
    mv      a5, sp                           # read sp to argument 5
    lw      a6, 32(sp)                       # read fp to argument 6
    call    APP_TRAP_HANDLER                 # call application trap handler
    csrw    mepc, a0                         # set returned value to mepc
#else
    csrr    a0, mcause                       # read trap cause CSR
    li      a1, 0x0000000B                   # load ecall trap cause value
    bne     a0, a1, trap_return              # branch if trap is not ecall
ecall_inc_pc:                                # _else: increment mepc to skip instruction
    csrr    a0, mepc                         # read mepc CSR
    addi    a0, a0, 4                        # increment mepc
    csrw    mepc, a0                         # write new value to mepc CSR
#endif

trap_return:
    RESTORE_CONTEXT
    mret
#endif

##################################
asm_putchar:
wait_uart0:
    li      t0, UART_STATUS_ADDR     # load UART status address
    lw      t1, 0(t0)                # load status into t1
    srl     t1, t1, 1                # shift t1 right by one bit
    and     t1, t1, 1                # filter uart ready status code
    li      t2, 1                    # load comparison value
    beq     t1, t2, wait_uart0       # branch if status is not ready
write_uart_byte:
    li      t0, UART_INTERFACE_ADDR
    sb      a0, 0(t0)
wait_uart1:
    li      t0, UART_STATUS_ADDR     # load UART status address
    lw      t1, 0(t0)                # load status into t1
    srl     t1, t1, 1                # shift t1 right by one bit
    and     t1, t1, 1                # filter uart ready status code
    li      t2, 1                    # load comparison value
    beq     t1, t2, wait_uart1       # branch if status is not ready
    ret                              # _else: return

##################################
asm_write_hex:
    mv      t6, ra                # save return address to t6
    mv      t3, a0                # save number to print to t3
    mv      t4, a1                # save number of digits to t4
awh_loop:
    addi    t4, t4, -1            # decrement number of digits
    sll     t1, t4, 2             # multiply number of digits by 4
    srl     t0, t3, t1            # shifts value for next digit
    andi    t0, t0, 0xF           # get one digit -> t5
    addi    t0, t0, 0x30          # increments 0x30 to convert to char
    li      t1, 0x39              # load comparison value
    ble     t0, t1, awh_print     # if digit is number [0-9], jumps to print
    addi    t0, t0, 0x7           # increment for hex char values [A-F]
awh_print:
    mv      a0, t0                # load char to argument
    call    asm_putchar           # call putchar function
awh_end_loop:
    bgt     t4, x0, awh_loop      # if number is greater than zero, loop
awh_end:
    li      a0, 0x0A              # load line break char
    call    asm_putchar           # call putchar function
    mv      ra, t6                # load return address
    ret

    .end
