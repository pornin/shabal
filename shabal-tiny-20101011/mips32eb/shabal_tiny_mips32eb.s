# Implementation of Shabal: MIPS, big-endian, 32-bit.
#
# This code is compatible with the MIPS I architecture, *including* the
# "load delay slot" restrictions which were removed in MIPS II and
# subsequent MIPS versions (a memory load instruction shall not be
# immediately followed by an instruction which uses the load target
# register as source operand).
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

	.file   1 "shabal_tiny_mips32eb.s"
	.section .mdebug.abi32
	.previous
	.abicalls
	.text

# byteswap(bb)
#    bb   pointer to a 64-byte buffer
#
# This function byteswaps the 16 words at the specified address. The buffer
# must be word-aligned. This function preserves $a0, $a1, $a2 and $a3;
# it modifies only the $t* registers.
#
	.align  2
	.ent    byteswap
	.type   byteswap, @function
byteswap:
	.frame  $sp,0,$31
	.set    noreorder
	.set    nomacro
	addiu   $t0, $0, 16            # Load loop counter.
	move    $t1, $a0               # Copy buffer address in $t1.
$Lbs0:
	lw      $t2, ($t1)             # Load word to byteswap.
	addiu   $t0, $t0, -1           # Decrement loop counter.
	sll     $t3, $t2, 24           # Extract byte 0, move to 3.
	andi    $t4, $t2, 0xFF00       # Extract byte 1.
	srl     $t5, $t2, 8            # Move byte 2 to 1.
	sll     $t4, $t4, 8            # Move byte 1 to 2.
	andi    $t5, $t5, 0xFF00       # Extract byte 2 (already moved to 1).
	srl     $t6, $t2, 24           # Extract byte 3, move to 0.
	or      $t3, $t3, $t4          # Combine bytes 2 and 3.
	or      $t5, $t5, $t6          # Combine bytes 0 and 1.
	addiu   $t1, $t1, 4            # Increment load address.
	or      $t2, $t3, $t5          # Combine all bytes.
	bne     $t0, $0, $Lbs0         # Loop 16 times.
	sw      $t2, -4($t1)           # Store byteswapped word (delay slot).

	jr      $31                    # Return.
	nop
	.set    macro
	.set    reorder
	.end    byteswap

# shabal_inner() computes the inner function (the W counter is
# not incremented). It receives a pointer to the context structure in $a0.
#
# This function preserves $a0, $a1, $a2 and $a3. It modifies only the $t*
# and $v* registers.
#
	.align  2
	.ent    shabal_inner
	.type   shabal_inner, @function
shabal_inner:
	.frame  $sp,256,$31
	.set    noreorder
	.set    nomacro
	addiu   $sp, $sp, -256         # Not a real frame (no room for $a*).

	addiu   $t0, $a0, 64           # Compute buffer limit.
	move    $t7, $sp               # $t7 indexes into Bx[].
$Li1:
	lw      $t1, ($a0)             # Get next M word.
	lw      $t2, 116($a0)          # Get next B word.
	addiu   $a0, $a0, 4            # Increment M pointer.
	addu    $t1, $t1, $t2          # Add M and B word.
	sll     $t2, $t1, 17           # Rotate addition result (part 1).
	srl     $t1, $t1, 15           # Rotate addition result (part 2).
	or      $t1, $t1, $t2          # Rotate addition result (part 3).
	sw      $t1, ($t7)             # Store new Bx word.
	bne     $a0, $t0, $Li1         # Loop.
	addiu   $t7, $t7, 4            # Increment Bx[] pointer (delay slot).

	# At that point, $a0 points to offset 64. We XOR the counter W
	# into A[0]/A[1].
	lw      $t0, 180($a0)
	lw      $t1, 184($a0)
	lw      $t2, 4($a0)
	lw      $t3, 8($a0)
	xor     $t0, $t0, $t2
	xor     $t1, $t1, $t3
	sw      $t0, 4($a0)
	sw      $t1, 8($a0)

	addiu   $a0, $a0, -64          # Reset $a0 to its original value.

	# In the loop below, the counter (in $t3) begins at 224 and is
	# decremented by 4 for every loop. The loop runs 48 times, i.e.
	# exits when $t3 reaches 32. From this counter, the indexes for
	# C[] and M[] can be easily computed.

	lw      $t0, 112($a0)          # Load ap (A[11]).
	addiu   $t3, $0, 224           # Set counter (224).
	addiu   $t5, $a0, 68           # Set pointer for A word.
	addiu   $v0, $a0, 116          # Compute limit for A[].

$Li2:
	sll     $t1, $t0, 15           # Rotate ap (part 1).
	srl     $t0, $t0, 17           # Rotate ap (part 2).
	lw      $t2, ($t5)             # Load A word.
	or      $t0, $t0, $t1          # Rotate ap (part 3).
	andi    $t4, $t3, 60           # Compute index for C word (part 1).
	sll     $t1, $t0, 2            # Multiply by 5 (part 1).
	addu    $t4, $a0, $t4          # Compute index for C word (part 2).
	addu    $t0, $t0, $t1          # Multiply by 5 (part 2).
	lw      $t8, 180($t4)          # Load C word.
	xor     $t0, $t2, $t0          # Xor old A word.
	lw      $v1, -12($t7)          # Load Bx[u + 13].
	xor     $t0, $t8               # Xor C word.
	lw      $t6, -40($t7)          # Load Bx[u + 6].
	sll     $t1, $t0, 1            # Multiply by 3 (part 1).
	lw      $t9, -28($t7)          # Load Bx[u + 9].
	addu    $t0, $t0, $t1          # Multiply by 3 (part 2).
	nor     $t6, $0, $t6           # Compute ~Bx[u + 6].
	xor     $t0, $t0, $v1          # Xor Bx[u + 13].
	and     $t6, $t6, $t9          # Compute (Bx[u + 9] & ~Bx[u + 6]).
	subu    $t4, $0, $t3           # Compute index for M word (part 1).
	xor     $t0, $t0, $t6          # Xor (Bx[u + 9] & ~Bx[u + 6]).
	addiu   $t4, $t4, 32           # Compute index for M word (part 2).
	lw      $t2, -64($t7)          # Load Bx[u].
	andi    $t4, $t4, 60           # Compute index for M word (part 3).
	sll     $t8, $t2, 1            # Rotate Bx[u] (part 1).
	addu    $t4, $a0, $t4          # Compute index for M word (part 4).
	srl     $t2, $t2, 31           # Rotate Bx[u] (part 2).
	lw      $t1, ($t4)             # Load M word.
	nor     $t2, $t2, $t8          # Rotate Bx[u] (part 3) and invert.
	xor     $t0, $t1, $t0          # Xor M word.
	addiu   $t3, $t3, -4           # Decrement loop counter.
	xor     $t2, $t2, $t0          # Xor with new A word.
	sw      $t0, ($t5)             # Store new A word.
	addiu   $t5, $t5, 4            # Increment A pointer.
	sw      $t2, ($t7)             # Store new Bx[] word.
	bne     $t5, $v0, $Li2         # Loop unless A[] limit reached.
	addiu   $t7, $t7, 4            # Increment Bx[] pointer (delay slot).

	subu    $t1, $t3, 32           # Check main counter with limit.
	bne     $t1, $0, $Li2          # Loop.
	addiu   $t5, $a0, 68           # Reset A[] pointer (delay slot).

	# Now the secondary loop, which adds the C[] words to the A[] words.
	# We loop 12 times, adding three C words to a A word per iteration.
	# This loop is slightly larger, but faster, than a 48-times loop
	# which adds one C word per iteration.

	move    $v0, $a0               # Set index for A/C words.
	addiu   $v1, $a0, 44           # Compute A[] upper limit.
	addiu   $t5, $0, 60            # Set counter for C words.
$Li3:
	addiu   $t8, $t5, -16          # Index for first C word (part 1).
	lw      $t0, 68($v0)           # Read A word (0 to 11).
	andi    $t8, $t8, 60           # Index for first C word (part 2).
	lw      $t1, 192($v0)          # Read third C word (3 to 14).
	addu    $t8, $a0, $t8          # Index for first C word (part 3).
	addu    $t6, $a0, $t5          # Index for second C word.
	lw      $t3, 180($t8)          # Read first C word.
	lw      $t2, 180($t6)          # Read second C word.
	addu    $t0, $t0, $t1          # Add third C word to A word.
	addu    $t2, $t2, $t3          # Add first C word to second C word.
	addu    $t0, $t0, $t2          # Add two C words to A word.
	addiu   $t5, $t5, 4            # Increment counter for C words.
	sw      $t0, 68($v0)           # Store new A word.
	andi    $t5, $t5, 60           # Adjust counter for C words.
	bne     $v0, $v1, $Li3         # Loop 12 times.
	addiu   $v0, $v0, 4            # Adjust A index (delay slot).

	# Subtract M words from C words, storing results in B. We also
	# copy the "true" B words (from Bx[]) into C[]. We loop backwards.

	addiu   $v0, $a0, 60           # Compute start index for M[].
$Li4:
	lw      $t0, ($v0)             # Load M word.
	lw      $t1, 180($v0)          # Load C word.
	lw      $t2, -4($t7)           # Load Bx word.
	subu    $t0, $t1, $t0          # Subtract M word from C word.
	addiu   $t7, $t7, -4           # Update Bx[] pointer.
	sw      $t0, 116($v0)          # Store new B word.
	sw      $t2, 180($v0)          # Store new C word.
	bne     $a0, $v0, $Li4         # Loop 16 times.
	addiu   $v0, $v0, -4           # Update M/B/C pointer (delay slot).

	jr      $31                    # Return.
	addiu   $sp, $sp, 256          # Remove frame (delay slot).
	.set    macro
	.set    reorder
	.end    shabal_inner

# internal_memcpy() roughly performs the job of a memcpy() call, with a
# lighter call convention.
# Arguments:
#   t0   destination
#   a1   source
#   t1   length (in bytes)
# The length MUST be non-zero. Side-effects:
#   a1 is increased by t1
#   t0 is increased by t1
#   t1 is set to zero
#   v0 and v1 are spilled
#
	.align  2
	.ent	internal_memcpy
	.type	internal_memcpy, @function
internal_memcpy:
	.frame  $sp,0,$31		# vars= 0, regs= 0/0, args= 0, gp= 0
	.mask   0x00000000,0
	.fmask  0x00000000,0
	.set    noreorder
	.set    nomacro

	# We use the unaligned word access opcodes to process bytes by
	# 32-bit words whenever possible. Note that the 'lwr' opcode is
	# in the branch delay slot and may thus read some more bytes
	# than necessary, but only from an aligned 32-bit word which
	# contains at least one readable byte; thus, this will not incur
	# any page fault.
	#
	# By simply removing the lines from '$Lmc1:' (inclusive) to
	# '$Lmc2:' (exclusive), one can have a slower (+2.25 cpb) but
	# shorter version of this function (-40 bytes).
$Lmc1:
	sltiu   $v0, $t1, 5            # Skip fast loop if 4 or less bytes.
	bne     $v0, $0, $Lmc2         # End job with slow loop.
	lwl     $v1, 0($a1)            # Load source word (part 1) (delay slot).
	lwr     $v1, 3($a1)            # Load source word (part 2).
	addiu   $a1, $a1, 4            # Increment source pointer.
	addiu   $t1, $t1, -4           # Decrement data length.
	swl     $v1, 0($t0)            # Store word (part 1).
	swr     $v1, 3($t0)            # Store word (part 2).
	b       $Lmc1                  # Loop.
	addiu   $t0, $t0, 4            # Increment dest pointer (delay slot).
$Lmc2:
	lbu     $v1, ($a1)             # Read next byte from source.
	addiu   $t1, $t1, -1           # Decrement loop counter.
	sb      $v1, ($t0)             # Store next byte into destination.
	addiu   $a1, $a1, 1            # Increment source pointer.
	bne     $t1, $0, $Lmc2         # Loop until counter is zero.
	addiu   $t0, $t0, 1            # Increment dest pointer (delay slot).
	jr      $31                    # Exit function.
	nop
	.set    macro
	.set    reorder
	.end    internal_memcpy

# shabal_init(sc, out_size)
#    sc         pointer to context structure
#    out_size   output size, in bits
#
	.align  2
	.globl  shabal_init
	.ent    shabal_init
	.type   shabal_init, @function
shabal_init:
	.frame  $sp,24,$31
	.set    noreorder
	.set    nomacro
	addiu   $sp, $sp, -24          # Reserve room for stack frame.
	sw      $31, 20($sp)           # Save link register.

	sw      $a1, 252($a0)          # Save output size (in bits).
	addiu   $t0, $a0, 60           # Compute limit offset for buffer.
$Lsi1:
	sw      $a1, ($a0)             # Store next input word.
	addiu   $a1, $a1, 1            # Increment for next input word.
	bne     $a0, $t0, $Lsi1        # Loop while not at buffer end.
	addiu   $a0, $a0, 4            # Increment store address (delay slot).

	addiu   $t0, $a0, 176          # Compute limit offset for zeroing.
$Lsi2:
	sw      $0, ($a0)              # Clear next word.
	bne     $a0, $t0, $Lsi2        # Loop while not at zone end.
	addiu   $a0, $a0, 4            # Increment store address (delay slot).

	nor     $t0, $0, $0            # Set $t0 to 0xFFFFFFFF
	sw      $t0, ($a0)             # Set Wlow.
	sw      $t0, 4($a0)            # Set Whigh.

	bal     shabal_inner           # Call inner fonction.
	addiu   $a0, -244              # Set $a0 back to structure (delay slot).

	addiu   $t0, $a0, 60           # Compute limit offset for buffer.
$Lsi3:
	sw      $a1, ($a0)             # Store next input word.
	addiu   $a1, $a1, 1            # Increment for next input word.
	bne     $a0, $t0, $Lsi3        # Loop while not at buffer end.
	addiu   $a0, $a0, 4            # Increment store address (delay slot).

	sw      $0, 180($a0)           # Set Wlow.
	sw      $0, 184($a0)           # Set Whigh.
	bal     shabal_inner           # Call inner fonction.
	addiu   $a0, -64               # Set $a0 back to structure (delay slot).

	addiu   $t0, $0, 1             # Set $t0 to 1
	lw      $31, 20($sp)           # Restore link register.
	sw      $t0, 244($a0)          # Set Wlow.
	jr      $31                    # Return.
	addiu   $sp, $sp, 24           # Remove stack frame (delay slot).
	.set    macro
	.set    reorder
	.end    shabal_init

# shabal(sc, data, len)
#    sc     pointer to context structure
#    data   input data
#    len    input data length (in bytes)
#
	.align  2
	.globl  shabal
	.ent    shabal
	.type   shabal, @function
shabal:
	.frame  $sp,24,$31
	.set    noreorder
	.set    nomacro
	addiu   $sp, $sp, -24          # Reserve room for stack frame.
	lw      $a3, 64($a0)           # Load sc->ptr into $a3.
	sw      $31, 20($sp)           # Save link register.
$Lsb1:
	beq     $a2, $0, $Lsb9         # Exit if len == 0.
	addiu   $t1, $0, 64            # Set $t1 to 64 (also delay slot).
	subu    $t1, $t1, $a3          # Compute 64-ptr in $t1.
	sltu    $t2, $a2, $t1          # Compare $t1 with len.
	beq     $t2, $0, $Lsb2         # If $t1 <= len, then jump.
	addu    $t0, $a0, $a3          # Compute dest pointer (delay slot).
	move    $t1, $a2               # Set $t1 to len (because len < $t1).
$Lsb2:
	addu    $a3, $a3, $t1          # Adjust ptr (post-copy).
	bal     internal_memcpy        # Copy data chunk.
	subu    $a2, $a2, $t1          # Adjust len (delay slot).
	sltiu   $t0, $a3, 64           # Compare ptr with 64.
	bne     $t0, $0, $Lsb9         # ptr < 64: all data processed.
	nop

	bal     byteswap               # Byteswap input words.
	nop
	bal     shabal_inner           # Call inner function.
	move    $a3, $0                # Reset ptr (delay slot).

	lw      $t0, 244($a0)          # Load Wlow.
	lw      $t1, 248($a0)          # Load Whigh.
	addiu   $t0, $t0, 1            # Increment Wlow.
	addiu   $t1, $t1, 1            # Increment Whigh.
	bne     $t0, $0, $Lsb1         # If not 0, no carry, just loop.
	sw      $t0, 244($a0)          # Store Wlow (delay slot).
	b       $Lsb1                  # Loop.
	sw      $t1, 248($a0)          # Store Whigh (delay slot).

$Lsb9:
	lw      $31, 20($sp)           # Restore saved link register.
	sw      $a3, 64($a0)           # Store back sc->ptr.
	jr      $31                    # Return.
	addiu   $sp, $sp, 24           # Remove stack frame (delay slot).
	.set    macro
	.set    reorder
	.end    shabal

# shabal_close(sc, ub, b, dst)
#    sc    pointer to context structure
#    ub    extra bits
#    n     number of extra bits (0 to 7)
#    dst   destination buffer
#
	.align  2
	.globl  shabal_close
	.ent    shabal_close
	.type   shabal_close, @function
shabal_close:
	.frame  $sp,24,$31
	.set    noreorder
	.set    nomacro
	addiu   $sp, $sp, -24          # Reserve room for stack frame.
	sw      $31, 20($sp)           # Save link register.

	addiu   $t0, $0, 128           # Set z ($t0) to 0x80.
	srlv    $t0, $t0, $a2          # Shift right z by n bits.
	lw      $t2, 64($a0)           # Get ptr.
	subu    $t1, $0, $t0           # Compute -z into $t1.
	and     $t1, $t1, $a1          # Compute (ub & -z) into $1.
	or      $t0, $t0, $t1          # Compute extra byte value into $1.
	addu    $t2, $a0, $t2          # Compute position for extra byte.
	sb      $t0, ($t2)             # Store extra byte.
	addiu   $t3, $a0, 63           # Compute buffer limit.
	beq     $t2, $t3, $Lsc2        # Skip loop if no zero byte. Note:
	                               # the addiu below is in the delay
				       # slot but is harmless.
$Lsc1:
	addiu   $t2, $t2, 1            # Increment buffer pointer.
	bne     $t2, $t3, $Lsc1        # Loop until buffer end.
	sw      $0, ($t2)              # Store padding zero byte (delay slot).

$Lsc2:
	bal     byteswap               # Byteswap input words.
	addiu   $a2, $0, 4             # Set loop counter (delay slot).
$Lsc3:
	bal     shabal_inner           # Call inner function.
	addiu   $a2, $a2, -1           # Decrement loop counter (delay slot).
	bne     $a2, $0, $Lsc3         # Loop four times.
	nop                            # (delay slot).

	addiu   $a1, $a0, 244          # Compute source, part 1.
	bal     byteswap               # Byteswap C words.
	addiu   $a0, $a0, 180          # Compute &C[0] (delay slot).
	lw      $t1, 72($a0)           # Load output size (bits).
	move    $t0, $a3               # Destination pointer is still in $a3.
	srl     $t1, $t1, 3            # Convert output size to bytes.
	bal     internal_memcpy        # Call copy function.
	subu    $a1, $a1, $t1          # Compute source, part 2 (delay slot).

	lw      $31, 20($sp)           # Restore saved link register.
	nop                            # load delay (MIPS I compat).
	jr      $31                    # Return.
	addiu   $sp, $sp, 24           # Remove stack frame (delay slot).
	.set    macro
	.set    reorder
	.end    shabal_close
