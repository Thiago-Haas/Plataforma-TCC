.section .rodata
helloworld_addr:  .asciz "Hello world\n"
print_int_addr:   .asciz "num: %d\n"
trap_addr:        .asciz "trap\n"
trap_info_addr:   .asciz "mepc: %08X\nmcause: %08X\n"

.section .text, "ax"
.global main
main:
    /* handle stack pointer to save return address */
    addi   sp, sp, -4            # decrement stack pointer
    sw     ra, 0(sp)             # save return address

    la     a0, helloworld_addr
    call   printf

    /* configure interrupts */
    # la    t0, app_trap_handler
    # csrw  mtvec, t0
    li    t0, 500000              # 10 ms @ 50 MHz
    csrw  0xBC0, t0

    li    t0, 0x880
    csrw  mie, t0        # enable timer interrupt 
    csrsi mstatus, 0x8    # enable interrupts

    /* application code */
app:
    la     a0, helloworld_addr
    csrci  mstatus, 0x8          # disable interrupts
    call   printf                # print to uart
    csrsi  mstatus, 0x8          # enable interrupts
    j      app                   # infinite loop

    /* handle stack pointer to load return address */
    lw     ra, 0(sp)             # get return address
    addi   sp, sp, 4             # increment stack pointer
    li     a0, 1                 # set return code
    ret                          # return

/*** TRAP HANDLER ***/
# .altmacro
# .align 4
# .macro SAVE_CONTEXT
#     addi sp, sp, -32*4
#     .set i, 0
#     .rept 31
#           save_gp %i
#           .set i, i+1
#     .endr
# .endm
# .macro save_gp i, basereg=sp
#     sw x\i, ((\i)*4)(\basereg)
# .endm
# .align 4
# .macro RESTORE_CONTEXT
#     .set i, 1
#     .rept 31
#           load_gp %i
#           .set i, i+1
#     .endr
#     addi sp, sp, 32*4
# .endm
# .macro load_gp i, basereg=sp
#     lw x\i, ((\i)*4)(\basereg)
# .endm
# app_trap_handler:
#     csrci  mstatus, 0x8      # disable interrupts
#     SAVE_CONTEXT
#     la     a0, trap_addr
#     call   printf
#     la     a0, trap_info_addr
#     csrr   a1, mepc
#     csrr   a2, mcause
#     call   printf
#     csrsi  mstatus, 0x8      # enable interrupts
#     RESTORE_CONTEXT
#     mret
