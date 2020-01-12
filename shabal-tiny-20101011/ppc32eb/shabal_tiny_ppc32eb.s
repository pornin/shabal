# Implementation of Shabal: PowerPC, big-endian, 32-bit.
#
# This code should run on any platform compatible with the 32-bit PowerPC
# specification, when the system convention is big-endian.
#
# -----------------------------------------------------------------------
# (c) 2010 SAPHIR project. This software is provided 'as-is', without
# any epxress or implied warranty. In no event will the authors be held
# liable for any damages arising from the use of this software.
#
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to no restriction.
#
# Technical remarks and questions can be addressed to:
# <thomas.pornin@cryptolog.com>
# -----------------------------------------------------------------------

	.file      "shabal_tiny_ppc32eb.s"
	.section   ".got2","aw"
	.section   ".text"

# shabal_inner() computes the inner function (without updating
# the W counter). It receives a pointer to the context structure in r3.
# This function alters registers r0, r5 to r12, cr and ctr only; r3 and
# r4 are NOT modified.
#
# This function does not need to save its link register into the caller's
# frame; this supports shabal_close() which calls shabal_inner() but
# does not setup a proper frame.
#
	.align  2
	.type   shabal_inner, @function
shabal_inner:
	stwu    1, -272(1)

	# Throughout this function, r12 points to the last computed
	# Bx word. Storage of a new Bx word uses a 'stwu' which
	# performs the store and updates r12 in one instruction.

	addi    12, 1, 12              # Set r12 to &Bx[-1].
	li      0, 16
	sub     5, 3, 12               # Set r5 for M indexed access with r12.
	mtctr   0                      # Set loop counter (16).
	addi    6, 5, 116              # Set r6 for B indexed access with r12.
.L0z1:
	lwbrx   8, 5, 12               # Load M word (with byte swap).
	lwzx    9, 6, 12               # Load B word.
	add     8, 8, 9                # Add B and M word.
	rotlwi  8, 8, 17               # Rotate sum result.
	stwu    8, 4(12)               # Store rotated sum result in Bx[].
	bdnz    .L0z1                  # Loop 16 times.

	lwz     5, 244(3)              # Load Wlow.
	lwz     7, 68(3)               # Load A[0].
	lwz     6, 248(3)              # Load Whigh.
	lwz     8, 72(3)               # Load A[1].
	xor     5, 5, 7                # Xor Wlow with A[0].
	xor     6, 6, 8                # Xor Whigh with A[1].
	stw     5, 68(3)               # Store updated A[0].
	stw     6, 72(3)               # Store updated A[1].

	# Main loop. The previous A word (ap) is in r5. The index for
	# the new A word is in r6 (index in bytes, counted from the
	# structure pointer, i.e. 68 to 112). r11 points to &C[0].
	# The loop counter is maintained in r0, from 224 downto 32
	# (exclusive) by -4 increments.

	li      0, 224                 # Set loop counter.
	lwz     5, 112(3)              # Load ap = A[11].
	li      6, 68                  # Set index for A.
	addi    11, 3, 180             # Compute base for C[].
.L0z2:
	andi.   8, 0, 60               # Compute index for C word.
	lwzx    7, 3, 6                # Load A word.
	rotlwi  5, 5, 15               # Rotate ap by 15 bits.
	lwzx    8, 8, 11               # Load C word.
	mulli   5, 5, 5                # Multiply by 5.
	lwz     9, -8(12)              # Load Bx[u + 13].
	lwz     10, -24(12)            # Load Bx[u + 9].
	xor     5, 5, 7                # Xor A word.
	lwz     7, -36(12)             # Load Bx[u + 6].
	xor     5, 5, 8                # Xor C word.
	subfic  8, 0, 32               # Compute index for M word (part 1).
	mulli   5, 5, 3                # Multiply by 3.
	andi.   8, 8, 60               # Compute index for M word (part 2).
	andc    10, 10, 7              # Compute (Bx[u + 9] & ~Bx[u + 6]).
	xor     5, 5, 9                # Xor Bx[u + 13].
	lwbrx   8, 3, 8                # Load M word (with byte swap).
	xor     5, 5, 10               # Xor (Bx[u + 9] & ~Bx[u + 6]).
	lwz     9, -60(12)             # Load Bx[u].
	xor     5, 5, 8                # Xor M word.
	rotlwi  9, 9, 1                # Rotate Bx[u] by 1 bit.
	stwx    5, 3, 6                # Store new A word.
	addi    6, 6, 4                # Increment A word pointer.
	eqv     9, 9, 5                # Compute new Bx[u + 16].
	addic   0, 0, -4               # Decrement loop counter.
	cmplwi  6, 116                 # Compare A word pointer with A[] limit.
	stwu    9, 4(12)               # Store Bx[u + 16].
	bne     .L0z2                  # Loop (not at end of A[]).
	li      6, 68                  # Reset index for A.
	cmplwi  0, 32                  # Check for end of main loop.
	bne     .L0z2                  # Loop (end of A[]).

	# Secondary loop: add C words to A words. We use r6 to index A
	# words (direct pointer) and r7 as index for C words (12 to 56,
	# +4 increments, r11 is used as base and is already set).

	li      0, 12
	mtctr   0                      # Set loop counter (12).
	addi    6, 3, 64               # Set pointer for A words (&A[-1]).
	li      7, 12                  # Set index for C words.
.L0z3:
	lwzu    5, 4(6)                # Load A word, update r6.
	addi    8, 7, 32               # Compute first C word index (part 1).
	lwzx    10, 11, 7              # Load third C word.
	addi    9, 7, 48               # Compute second C word index (part 1).
	andi.   8, 8, 60               # Compute first C word index (part 2).
	add     5, 5, 10               # Add third C word to A word.
	andi.   9, 9, 60               # Compute second C word index (part 2).
	lwzx    8, 11, 8               # Load first C word.
	lwzx    9, 11, 9               # Load second C word.
	add     5, 5, 8                # Add first C word to A word.
	addi    7, 7, 4                # Increment C word index.
	add     5, 5, 9                # Add second C word to A word.
	stw     5, 0(6)                # Store new A word value.
	bdnz    .L0z3                  # Loop 12 times.

	# Now, subtract M words from C words and swap B with C. The real
	# B is in Bx[]. We loop backwards, using r6 as loop counter
	# (scaled 4 times, 64 to 4). r11 is the base for C[] (already set).
	# r10 is the base for B[]. r12 is used to access Bx[].

	addi    12, 12, 4              # Adjust Bx[] pointer.
	li      6, 64                  # Set loop counter.
	addi    10, 3, 116             # Compute base for B[].
.L0z4:
	lwzu    8, -4(12)              # Load B word (from Bx[]).
	addic.  6, 6, -4               # Decrement loop counter.
	lwbrx   5, 3, 6                # Read M word (with byte swap).
	lwzx    7, 11, 6               # Read C word.
	stwx    8, 11, 6               # Store new C word.
	sub     7, 7, 5                # Subtract M word from C word.
	stwx    7, 10, 6               # Store new B word.
	bne     .L0z4                  # Loop 16 times.

	addi    1, 1, 272
	blr
	.size   shabal_inner, .-shabal_inner

# shabal_close(sc, ub, n, dst)
#    sc    pointer to context structure
#    ub    extra final bits
#    n     number of extra bits (0 to 7)
#    dst   destination buffer for hash result
#
	.align  2
	.globl  shabal_close
	.type   shabal_close, @function
shabal_close:
	stwu    1, -16(1)
	mflr    0
	stw     0, 20(1)
	stw     3, 8(1)                # Save context pointer.
	stw     6, 12(1)               # Save destination buffer.

	li      7, 0x80                # Set r7 with padding byte.
	srw     7, 7, 5                # Compute z = 0x80 >> n.
	neg     8, 7                   # Compute -z.
	and     4, 4, 8                # Compute (ub & -z).
	or      4, 4, 7                # Compute (ub & -z) | z.

	lwz     9, 64(3)               # Load sc->ptr into r9.
	stbux   4, 3, 9                # Store extra byte.

	# We actually write one more zero byte than necessary, which
	# avoids a specific test. The extra byte goes to the upper
	# byte of sc->ptr, which is already zero anyway.
	subfic  5, 9, 64               # Compute 64-ptr.
	li      4, 0
	addi    3, 3, 1
	bl      memset@plt

	lwz     3, 8(1)
	bl      shabal_inner@local
	bl      shabal_inner@local
	bl      shabal_inner@local
	bl      shabal_inner@local

	lwz     5, 252(3)              # Get output size (in bits).
	lwz     4, 12(1)               # Restore destination buffer.
	srwi    5, 5, 3                # Convert output size to bytes.
	addi    3, 3, 244              # Get C array end pointer.
	sub     3, 3, 5                # Compute base for C words.
.L0c1:
	addic.  5, 5, -4               # Decrement loop counter.
	lwbrx   6, 3, 5                # Load C word (with byte swap).
	stwx    6, 4, 5                # Store output word.
	bne     .L0c1

	lwz     0, 20(1)
	mtlr    0
	addi    1, 1, 16
	blr
	.size   shabal_close, .-shabal_close

# shabal(sc, data, len)
#    sc     pointer to context structure
#    data   input data
#    len    input data length (in bytes)
#
	.align  2
	.globl  shabal
	.type   shabal, @function
shabal:
	stwu    1, -32(1)              # Create stack frame.
	mflr    0                      # Get link register into r0.
	stmw    28, 8(1)               # Save r28..31.
	stw     0, 36(1)               # Save link value into caller's frame.

	# Conventions:
	#    r28   context structure and data buffer
	#    r29   source data pointer
	#    r30   source data length
	#    r31   sc->ptr
	mr      28, 3
	mr      29, 4
	mr      30, 5
	lwz     31, 64(28)
.L0m1:
	cmpwi   30, 0                  # Compare len with 0.
	beq     .L0m9                  # Exit if no more data.
	subfic  5, 31, 64              # Compute 64-ptr.
	cmplw   0, 5, 30               # Compare len with 64-ptr.
	ble     .L0m2
	mr      5, 30                  # Set r5 = min(len, 64-ptr).
.L0m2:
	add     3, 28, 31              # Compute copy destination.
	mr      4, 29                  # Set copy source (current data).
	add     29, 29, 5              # Update data pointer.
	sub     30, 30, 5              # Update remaining data length.
	add     31, 31, 5              # Update ptr.
	bl      memcpy@plt             # Copy the data.
	cmplwi  31, 64                 # Compare ptr with 64.
	bne     .L0m9                  # If ptr != 64 then we are finished.
	mr      3, 28                  # Set context pointer.
	bl      shabal_inner@local     # Call inner function.
	li      31, 0                  # Reset ptr to 0.
	lwz     7, 244(28)             # Load Wlow.
	lwz     8, 248(28)             # Load Whigh.
	addic.  7, 7, 1                # Increment Wlow.
	addze   8, 8                   # Propagate carry in Whigh.
	stw     7, 244(28)             # Store back Wlow.
	stw     8, 248(28)             # Store back Whigh.
	b       .L0m1                  # Loop.

.L0m9:
	stw     31, 64(28)             # Store back sc->ptr.
	lwz     0, 36(1)               # Load link value.
	lmw     28, 8(1)               # Restore r28..31.
	mtlr    0                      # Restore lr.
	addi    1, 1, 32               # Remove stack frame.
	blr                            # Return.
	.size   shabal, .-shabal

# shabal_init(sc, out_size)
#    sc         pointer to context structure
#    out_size   Shabal output size, in bits
#
	.align  2
	.globl  shabal_init
	.type   shabal_init, @function
shabal_init:
	# We do not need a frame because we have no value to save (except
	# lr, which goes in the caller's frame) and we call only
	# shabal_inner(), which has a kind of frame but does not need
	# to save its lr.
	mflr    0
	stw     0, 4(1)

	stw     4, 252(3)              # Store output size.

	addi    3, 3, 60               # Set r3 to offset 60.
	li      5, -64                 # Set word index (from r3).
.L0i1:
	addic.  5, 5, 4                # Update word index.
	stwbrx  4, 3, 5                # Store prefix word (little-endian).
	addi    4, 4, 1                # Update for next prefix word.
	bne     .L0i1                  # Loop 16 times.

	addi    5, 3, 180              # Set limit for bzero.
	li      6, 0                   # Set filling word (zero).
.L0i2:
	stwu    6, 4(3)                # Clear next word.
	cmplw   3, 5                   # Compare address with bzero limit.
	bne     .L0i2                  # Loop 45 times.

	li      6, -1
	stw     6, 4(3)                # Set Wlow to -1.
	stw     6, 8(3)                # Set Whigh to -1.

	addi    3, 3, -240             # Set back r3 to context structure.
	bl      shabal_inner@local     # Call inner function.

	addi    3, 3, 60               # Set r3 to offset 60.
	li      5, -64                 # Set word index (from r3).
.L0i3:
	addic.  5, 5, 4                # Update word index.
	stwbrx  4, 3, 5                # Store prefix word (little-endian).
	addi    4, 4, 1                # Update for next prefix word.
	bne     .L0i3                  # Loop 16 times.

	addi    3, 3, -60              # Set back r3 to context structure.
	li      6, 0
	stw     6, 244(3)              # Set Wlow to 0.
	stw     6, 248(3)              # Set Whigh to 0.
	bl      shabal_inner@local     # Call inner function.

	li      6, 1
	stw     6, 244(3)              # Set Wlow to 1.

	lwz     0, 4(1)
	mtlr    0
	blr
	.size   shabal_init, .-shabal_init
