@ Implementation of Shabal: ARM, little-endian, Thumb-only.
@
@ This implementation uses only Thumb opcodes. It is more compact than
@ the mixed ARM/Thumb implementation, but also slower. It should run
@ on all Thumb-capable ARM processors, including the Cortex-M systems.
@ This implementation supports interworking.
@
@ This code is compatible with APCS/ATPCS (old-style call conventions)
@ and AAPCS (new-style, "EABI" conventions). The AAPCS mandates 8-byte
@ stack alignment for calls to public functions, which is why shabal()
@ appears to needlessly save the "a4" scratch register: this keeps the
@ stack aligned for the call to memcpy().
@
@ -----------------------------------------------------------------------
@ (c) 2010 SAPHIR project. This software is provided 'as-is', without
@ any epxress or implied warranty. In no event will the authors be held
@ liable for any damages arising from the use of this software.
@
@ Permission is granted to anyone to use this software for any purpose,
@ including commercial applications, and to alter it and redistribute it
@ freely, subject to no restriction.
@
@ Technical remarks and questions can be addressed to:
@ <thomas.pornin@cryptolog.com>
@ -----------------------------------------------------------------------

	.code   16
	.file   "shabal_tiny_armel_thumb.s"
	.text

@ shabal_inner(sc)
@    sc   pointer to context structure
@
@ This function actually expects its argument in v1, not a1. Registers a1-a4
@ may be modified.
@
	.align  2
	.code   16
	.thumb_func
	.type   shabal_inner, %function
shabal_inner:
	push    {v1 - v4, lr}          @ Save registers.
	sub     sp, #264               @ Allocate Bx[] buffer and some locals.
	str     v1, [sp, #256]         @ Save pointer to context structure.

	@ Throughout the function, v4 will point somewhere in the Bx[]
	@ array.
	mov     v4, sp

	mov     a3, #16                @ Set loop counter.
	mov     a4, #15                @ Rotate count.
.L0m:
	ldr     a1, [v1]               @ Load next M word.
	ldr     a2, [v1, #116]         @ Load next B word.
	add     a1, a1, a2             @ Add M word to B word.
	ror     a1, a4                 @ Rotate B word.
	stmia   v4!, {a1}              @ Store new B word (in Bx[]).
	add     v1, #4                 @ Increment M/B pointer.
	sub     a3, #1                 @ Decrement loop counter.
	bne     .L0m                   @ Loop 16 times.

	@ At that point, v1 points to offset 64.
	add     v2, v1, #4             @ Compute &A[0].
	add     v1, #180               @ Compute pointer to W.
	ldmia   v2!, {a1, a2}          @ Load A[0]/A[1].
	ldmia   v1!, {a3, a4}          @ Load Wlow/Whigh.
	eor     a1, a3                 @ Xor Wlow with A[0].
	eor     a2, a4                 @ Xor Whigh with A[1].
	sub     v2, #8                 @ Compute &A[0].
	stmia   v2!, {a1, a2}          @ Store new A[0]/A[1].

	@ Conventions for next loop:
	@   v2   points to A[0], updated
	@   a4   loop counter, 224 downto 32, -4 increments
	@ A pointer to the context is kept in [sp+256].
	@ A pointer to C[0] is kept in [sp+260].

	sub     v1, #72                @ Compute &C[0].
	sub     v2, #8                 @ Compute &A[0].
	str     v1, [sp, #260]         @ Store &C[0].
	mov     a4, #224               @ Set loop counter.
	ldr     a1, [v2, #44]          @ Load A[11].

.L1m:
	mov     a2, #17                @ Load a2 with rotation count.
	mov     v3, #60                @ Set v3 to 4*0xF mask.
	ror     a1, a2                 @ Rotate previous A word.
	and     v3, a4                 @ Compute index for C word.
	lsl     a2, a1, #2             @ Multiply by 5 (part 1).
	ldr     v1, [sp, #260]         @ Load pointer to C[0].
	add     a1, a2                 @ Multiply by 5 (part 2).
	ldr     a3, [v2]               @ Load A word.
	sub     v4, #64                @ Adjust v4 for Bx[] access.
	ldr     v3, [v1, v3]           @ Load C word.
	eor     a1, a3                 @ Xor A word.
	ldr     a2, [v4, #24]          @ Load Bx[u + 6].
	eor     a1, v3                 @ Xor C word.
	ldr     v3, [v4, #36]          @ Load Bx[u + 9].
	lsl     a3, a1, #1             @ Multiply by 3 (part 1).
	ldr     v1, [v4, #52]          @ Load Bx[u + 13].
	add     a1, a3                 @ Multiply by 3 (part 2).
	bic     v3, a2                 @ Compute (Bx[u + 9] & ~Bx[u + 6]).
	mov     a2, #32                @ Compute index for M word (part 1).
	eor     a1, v1                 @ Xor Bx[u + 13].
	mov     v1, #60                @ Compute index for M word (part 2).
	sub     a2, a2, a4             @ Compute index for M word (part 3).
	eor     a1, v3                 @ Xor (Bx[u + 9] & ~Bx[u + 6]).
	ldr     v3, [sp, #256]         @ Get pointer to context structure.
	and     v1, a2                 @ Compute index for M word (part 4).
	mov     a3, #31                @ Load a3 with rotation count.
	ldr     v1, [v3, v1]           @ Get M word.
	ldr     a2, [v4]               @ Load Bx[u].
	eor     a1, v1                 @ Xor M word.
	add     v4, #64                @ Adjust v4 for Bx[] access.
	ror     a2, a3                 @ Rotate Bx[u].
	stmia   v2!, {a1}              @ Store new A word, update v2.
	mvn     a2, a2                 @ Compute ~rol(Bx[u], 1).
	add     v3, #116               @ Compute &B[0].
	eor     a2, a1                 @ Xor with new A word.
	sub     a4, #4                 @ Decrement loop counter.
	stmia   v4!, {a2}              @ Store new B word, update v4.
	cmp     v2, v3                 @ Compare A pointer with &B[0].
	bne     .L1m
	sub     v2, #48                @ Reset A pointer.
	cmp     a4, #32                @ Test end of loop.
	bne     .L1m

	@ At that point, v2 points to A[0], v3 points to B[0].
	@ Conventions for next loop:
	@   v2   points to A[0], updated
	@   v3   points to C[0]
	@   a3   index for first C word, scaled (44 to 24, +4 inc, mod 64)
	@   v1   60 (mask for C word indexes)

	add     v3, #64                @ Set v3 to &C[0].
	mov     a3, #44                @ Set index for first C word.
	mov     v1, #60                @ Set 4*0xF mask.
.L2m:
	ldr     a1, [v2]               @ Load A word.
	ldr     a4, [v3, a3]           @ Load first C word.
	add     a3, #16                @ Index for second C word (part 1).
	ldr     a2, [v2, #124]         @ Load third C word.
	add     a1, a4                 @ Add first C word.
	and     a3, v1                 @ Index for second C word (part 2).
	ldr     a4, [v3, a3]           @ Load second C word.
	add     a1, a2                 @ Add third C word.
	sub     a3, #12                @ Compute next index (part 1).
	add     a1, a4                 @ Add second C word.
	and     a3, v1                 @ Compute next index (part 2).
	stmia   v2!, {a1}              @ Store new A word, update v2.
	cmp     a3, #28                @ Test end of loop.
	bne     .L2m

	@ Conventions for next loop:
	@   v1   pointer to M word, updated
	@   v2   pointer to &B[0], updated
	@   v3   pointer to &C[0], updated
	@   v4   pointer to B word (in Bx[]), updated
	@   a4   loop counter

	ldr     v1, [sp, #256]         @ Load pointer to context.
	sub     v4, #64                @ Adjust v4 for Bx[] access.
	mov     a4, #16                @ Set loop counter.
.L3m:
	ldmia   v1!, {a1}              @ Load M word, update v1.
	ldr     a2, [v3]               @ Load C word.
	ldmia   v4!, {a3}              @ Load B word, update v4.
	sub     a2, a1                 @ Compute new B word.
	stmia   v2!, {a2}              @ Store new B word, update v2.
	sub     a4, #1                 @ Decrement loop counter.
	stmia   v3!, {a3}              @ Store new C word, update v3.
	bne     .L3m                   @ Loop 16 times.

	add     sp, #264               @ Remove locals.
	pop     {v1 - v4, pc}          @ Restore registers and return.
	.size   shabal_inner, .-shabal_inner

@ shabal_close(sc, ub, n, dst)
@    sc    pointer to context structure
@    ub    extra bits
@    n     number of extra bits
@    dst   destination buffer
@
	.align  2
	.global shabal_close
	.code   16
	.thumb_func
	.type   shabal_close, %function
shabal_close:
	push    {v1 - v3, lr}          @ Save registers.

	@ Compute extra byte into a2.
	mov     v1, #0x80
	lsr     v1, a3
	neg     v2, v1
	and     a2, v2
	orr     a2, v1

	ldr     v2, [a1, #64]          @ Read sc->ptr into v2.
	mov     v1, a1                 @ Save context pointer.
	strb    a2, [a1, v2]           @ Store extra byte.

	@ The loop below clears the rest of the buffer, and one more
	@ byte after that (lsb of the ptr field), which is harmless.

	mov     a2, #0                 @ Clear a2.
.L0c:
	add     v2, #1                 @ Increment data index.
	strb    a2, [a1, v2]           @ Store one extra zero byte.
	cmp     v2, #64                @ Loop until we exceed buffer.
	bne     .L0c

	mov     v2, a4                 @ Save destination buffer.
	mov     v3, #4                 @ Set loop counter.
.L1c:
	bl      shabal_inner           @ Call inner function.
	sub     v3, #1                 @ Decrement loop counter.
	bne     .L1c                   @ Loop 4 times.

	add     v1, #244               @ Set v1 to address of W field.
	ldr     a3, [v1, #8]           @ Load output size (in bits).
	mov     a1, v2                 @ Set destination pointer.
	lsr     a3, a3, #3             @ Convert output size to bytes.
	sub     a2, v1, a3             @ Compute source address.
	bl      memcpy                 @ Copy result.

	pop     {v1 - v3}              @ Restore registers.
	pop     {a1}                   @ Return (interwork compatible).
	bx      a1
	.size   shabal_close, .-shabal_close

@ shabal_init(sc, out_size)
@    sc         pointer to context structure
@    out_size   hash output size (in bits)
@
	.align  2
	.global shabal_init
	.code   16
	.thumb_func
	.type   shabal_init, %function
shabal_init:
	push    {v1 - v3, lr}          @ Save registers.

	mov     a4, a2                 @ Copy out_size to a4.
	mov     v1, a1                 @ Save pointer to structure.
	mov     a3, #16                @ Counter for first loop.
.L0i:
	stmia   a1!, {a2}              @ Store next input word.
	add     a2, a2, #1             @ Increment input word.
	sub     a3, a3, #1             @ Decrement loop counter.
	bne     .L0i                   @ Loop 16 times.

	mov     v2, a2                 @ Save current input word.
	mov     a3, #45                @ Counter for second loop.
	mov     a2, #0
.L1i:
	stmia   a1!, {a2}              @ Clear next word.
	sub     a3, a3, #1             @ Decrement loop counter.
	bne     .L1i                   @ Loop 45 times.

	sub     a2, a2, #1             @ Set a2 to -1.
	mov     a3, a2                 @ Set a3 to -1.
	mov     v3, a1                 @ Save pointer to W.
	stmia   a1!, {a2, a3, a4}      @ Store Wlow, Whigh and out_size.

	bl      shabal_inner           @ Call inner function.

	mov     a3, #16                @ Counter for third loop.
.L2i:
	stmia   v1!, {v2}              @ Store next input word.
	add     v2, v2, #1             @ Increment input word.
	sub     a3, a3, #1             @ Decrement loop counter.
	bne     .L2i                   @ Loop 16 times.

	@ At that point, a3 = 0.

	sub     v1, #64                @ Recover pointer to structure.
	mov     a2, #0
	stmia   v3!, {a2, a3}          @ Set W to (0, 0).
	bl      shabal_inner           @ Call inner function.
	sub     v3, #8                 @ Recover pointer to W.
	mov     a1, #1
	str     a1, [v3]               @ Set Wlow = 1.

	pop     {v1 - v3}              @ Restore registers.
	pop     {a1}                   @ Return (interwork compatible).
	bx      a1
	.size   shabal_init, .-shabal_init

@ shabal(sc, data, len)
@    sc     pointer to context structure
@    data   pointer to input data
@    len    input data length (in bytes)
@
	.align  2
	.global shabal
	.code   16
	.thumb_func
	.type   shabal, %function
shabal:
	push    {a1 - a4, v1 - v4, lr} @ Save some registers.
	pop     {v1 - v3}              @ Reload  v1..v3 with the arguments.

	@ Conventions:
	@   v1   pointer to context structure
	@   v2   pointer to data
	@   v3   remaining data length
	@   v4   cache of sc->ptr

	ldr     v4, [v1, #64]
.L0s:
	cmp     v3, #0
	bne     .L2s
.L1s:
	str     v4, [v1, #64]          @ Store sc->ptr.
	pop     {a1, v1 - v4}          @ Restore registers.
	pop     {a1}                   @ Return (interwork compatible).
	bx      a1
.L2s:
	mov     a3, #64                @ Compute room in sc->buf (part 1).
	sub     a3, a3, v4             @ Compute room in sc->buf (part 2).
	cmp     v3, a3                 @ See if enough remaining data.
	bhs     .L3s
	mov     a3, v3                 @ Set a3 = min(64-ptr, len).
.L3s:
	sub     v3, v3, a3             @ Decrement len.
	mov     a2, v2                 @ Set source in a2.
	add     v2, v2, a3             @ Increment data pointer.
	add     a1, v1, v4             @ Compute destination in a1.
	add     v4, v4, a3             @ Update ptr.
	bl      memcpy                 @ Copy data into buffer.
	cmp     v4, #64                @ If not full buffer, then exit.
	bne     .L1s
	bl      shabal_inner           @ Call inner function.
	mov     a3, v1                 @ Compute access pointer for W (part 1).
	add     a3, #244               @ Compute access pointer for W (part 2).
	ldr     a1, [a3]               @ Load Wlow.
	ldr     a2, [a3, #4]           @ Load Whigh.
	mov     v4, #0                 @ Clear ptr.
	add     a1, #1                 @ Increment Wlow.
	adc     a2, v4                 @ Propagate carry into Whigh.
	str     a1, [a3]               @ Store Wlow.
	str     a2, [a3, #4]           @ Store Whigh.
	b       .L0s                   @ Loop.
	.size   shabal, .-shabal
