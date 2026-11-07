@ Minimal _start for QNX 6.5 ARM (same layout as the crt1 of dn00's f60-probe):
@ _init_libc(argc, argv, envp, auxv, exitfunc), then main(argc, argv, envp), then exit(ret)
	.text
	.arm
	.globl _start
	.type _start,%function
_start:
	mov	r4, r0			@ exitfunc passed by the loader
	ldr	r0, [sp]		@ argc
	add	r1, sp, #4		@ argv
	add	r2, r1, r0, lsl #2
	add	r2, r2, #4		@ envp
	mov	r3, r2
1:	ldr	r12, [r3], #4		@ skip envp up to the NULL -> r3 = auxv
	teq	r12, #0
	bne	1b
	str	r4, [sp, #-4]!		@ 5th argument: exitfunc
	mov	r4, r0
	mov	r5, r1
	mov	r6, r2
	bl	_init_libc
	add	sp, sp, #4
	mov	r0, r4
	mov	r1, r5
	mov	r2, r6
	bl	main
	bl	exit
2:	b	2b

@ QNX note (type 3 = stack), same as f60-probe: default stack size
	.section .note.qnx,"a",%note
	.balign 4
	.long 4			@ namesz
	.long 8			@ descsz
	.long 3			@ type
	.asciz "QNX"
	.long 0
	.long 0x1000
