# Implementation of Shabal: i386 (32-bit x86).
#
# This code is compatible with the original Intel 80386, and all subsequent
# x86-compatible processors.
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

	.file	"shabal_tiny_i386.s"
	.text

	.type	shabal_inner, @function
shabal_inner:
	# Arguments:
	#   pointer to shabal_context

	# We reserve a 256-byte area to hold the 64 intermediate B words.
	# This allows for faster and smaller access to those words from
	# the main loop; it also simplifies the final B/C swap.
	pushl   %ebx
	pushl   %edi
	pushl   %esi
	movl    16(%esp), %esi         # Get pointer to context structure
	enter   $256, $0

	# The intermediate B words are in the stack-based array allocated
	# above; we call it Bx[]. At that point, the buffer low address
	# is equal to %esp, and its high address is %ebp-4

	# Add message words to B; also rotate B words by 17 bits and
	# write the new B words in the Bx[] array.
	# Note:
	#   %esi   pointer to current data word
	#   %edi   pointer to the location of the new B word (in Bx[])
	xorl    %ecx, %ecx
	movb    $16, %cl
	movl    %esp, %edi             # Address of Bx[0].
.Lshabal_inner_loop1:
	lodsl                          # Load M word.
	addl    112(%esi), %eax        # Get B word and add to M word.
	roll    $17, %eax              # Rotate new B word.
	decl    %ecx
	stosl                          # Store new B word.
	jnz     .Lshabal_inner_loop1

	# Xor counter W to A[0]/A[1]; at that point, %esi points to
	# offset 64 in the context structure.
	movl    180(%esi), %eax        # Read W low word.
	movl    184(%esi), %edx        # Read W high word.
	xorl    %eax, 4(%esi)          # Xor W_low into A[0].
	xorl    %edx, 8(%esi)          # Xor W_high into A[1].

	# Main loop: 48 iterations
	#   %ebx   previously modified A word ('ap')
	#   %esi   pointer to A[0]
	#   %edi   pointer to new value of B, in Bx[]
	#   %edx   counter for A words (0 to 11, four times)
	#   %ecx counts down from 48 downto 1
	movb    $48, %cl
	movl    48(%esi), %ebx
	leal    4(%esi), %esi
	xorl    %edx, %edx
.Lshabal_inner_loop2:
	roll    $15, %ebx              # Rotate previous A word by 15 bits.
	pushl   %ecx                   # Save counter.
	addl    $8, %ecx               # Compute index for C word (part 1).
	leal    (%ebx,%ebx,4), %ebx    # Multiply rotated A word by 5.
	andl    $15, %ecx              # Compute index for C word (part 2).
	xorl    (%esi,%edx,4), %ebx    # Get old A word, xor it.
	xorl    112(%esi,%ecx,4), %ebx # Get C word, xor it.
	negl    %ecx                   # Reverse counter for M index
	leal    (%ebx,%ebx,2), %ebx    # Mutiply current value by 3.
	movl    -40(%edi), %eax        # Get B(u+6).
	addl    $8, %ecx               # Compute index for M word (part 1).
	xorl    -12(%edi), %ebx        # Get B(u+13), xor it with current.
	notl    %eax                   # Invert B(u+6).
	andl    $15, %ecx              # Compute index for M word (part 2).
	andl    -28(%edi), %eax        # Get B(u+9), combine with ~B(u+6).
	xorl    %eax, %ebx             # Xor (B(u+9) & ~B(u+6)) with current.
	movl    -64(%edi), %eax        # Get B(u).
	xorl    -68(%esi,%ecx,4), %ebx # Get M(u), xor it with current.
	notl    %eax                   # Invert B(u).
	popl    %ecx                   # Recover loop counter.
	roll    $1, %eax               # Rotate ~B(u) by 1 bit.
	decl    %ecx                   # Decrement loop counter.
	xorl    %ebx, %eax             # Xor new A word with rotated ~B(u).
	movl    %ebx, (%esi,%edx,4)    # Store new A word.
	incl    %edx                   # Adjust counter for A.
	stosl                          # Store new B word.
	cmpl    $12, %edx
	jne     .Lshabal_inner_loop2
	xorl    %edx, %edx
	testl   %ecx, %ecx             # %ecx can be 0 only if %edx = 0
	jnz     .Lshabal_inner_loop2

	# Secondary loop: add three C words to each A word.
	#   %esi   points to A[0]
	#   %edx   counter into A[] (+1, not scaled)
	#   %ecx   loop meta-counter, 3 downto 1 (inclusive)
	movb    $12, %dl
	xorl    %eax, %eax
	movb    $6, %al
	movb    $3, %cl
.Lshabal_inner_loop3:
	movl    112(%esi,%eax,4), %ebx
	decl    %eax
	addl    %ebx, -4(%esi,%edx,4)
	andl    $15, %eax
	decl    %edx
	jnz     .Lshabal_inner_loop3
	decl    %ecx
	movb    $12, %dl
	jnz     .Lshabal_inner_loop3

	# Subtract M words from C words, storing results in B. The "true"
	# B words are in Bx[], so we can handle them afterwards. At
	# that point, %esi points to A[0].
	#   %esi   pointer to current M word
	#   %edi   pointer to emplacement for new C word (in B[])
	movb    $16, %cl
	leal    48(%esi), %edi
	leal    -68(%esi), %esi
.Lshabal_inner_loop4:
	lodsl                          # Load next M word into %eax.
	negl    %eax                   # Compute -M.
	addl    64(%edi), %eax         # Load next C word, add it to -M.
	decl    %ecx
	stosl                          # Store result in B.
	jnz     .Lshabal_inner_loop4

	# Now we must copy the B words (those on top of Bx[]) into C.
	# At that point, %edi already points to C[0]. The first B word
	# is Bx[48], located from %ebp (which points at the virtual Bx[64]).
	leal    -64(%ebp), %esi
	movb    $16, %cl
	rep movsl

	leave
	popl    %esi
	popl    %edi
	popl    %ebx
	ret
	.size	shabal_inner, .-shabal_inner

.globl shabal_close
	.type	shabal_close, @function
shabal_close:
	# Arguments:
	#   sc    pointer to shabal_context
	#   ub    extra byte value
	#   n     number of bits in ub (0..7)
	#   dst   destination buffer for hash value

	pushl   %edi
	pushl   %esi

	# Here we load the arguments, which are on the stack. Memory
	# accesses relative to %esp with an index yield big opcodes;
	# instead, we used lodsl to read the three first parameters.
	# After this sequence, %edi points to the context structure,
	# and %al contains the extra byte (extra bits + padding bit).
	leal    12(%esp), %esi
	lodsl                          # Load context pointer (sc).
	movl    %eax, %edi
	lodsl                          # Load extra byte value (ub).
	xorl    %edx, %edx
	movb    $128, %dl
	movl    (%esi), %ecx           # Load number of extra bits (n).
	shrl    %cl, %edx
	orl     %edx, %eax
	negl    %edx
	andl    %edx, %eax

	movl    64(%edi), %edx
	addl    %edx, %edi
	# Write last data / first padding byte.
	stosb
	# Append some zero bytes to complete buffer.
	# Warning: maybe no bytes are to be added, beware of 'rep'.
	xorl    %ecx, %ecx
	movb    $63, %cl
	subl    %edx, %ecx
	jz      .Lshabal_close_1
	xorb    %al, %al
	rep stosb

.Lshabal_close_1:
	# Process four times; counter is unchanged.
	movb    $4, %cl
	# At that point, %edi points to the structure offset 64.
	subl    $64, %edi
.Lshabal_close_loop:
	# Since some registers are not preserved by the call, we need
	# to save them. We also need to push the parameter for
	# shabal_inner() (currently in %edi).
	pushl   %ecx                   # Save counter (may be altered).
	pushl   %edi                   # Push argument (context address).
	call    shabal_inner
	popl    %eax                   # Dummy (remove function argument).
	popl    %ecx                   # Restore counter.
	loop    .Lshabal_close_loop

	# Hash result is in the 'C' variables.
	# We recover context address and destination address from stack.
	movl    12(%esp), %esi
	movl    24(%esp), %edi
	# Get the output size in bits, convert it to a number of 32-bit
	# words.
	movl    252(%esi), %ecx
	shrl    $5, %ecx
	# Compute start offset in C[].
	xorl    %edx, %edx
	movb    $61, %dl
	subl    %ecx, %edx
	leal    (%esi,%edx,4), %esi
	# Copy hash result and return.
	rep movsl
	popl    %esi
	popl    %edi
	ret
	.size	shabal_close, .-shabal_close

.globl shabal_init
	.type	shabal_init, @function
shabal_init:
	# Arguments:
	#   sc         pointer to shabal_context
	#   out_size   output size (in bits)

	pushl   %edi
	# Initialize buffer with first prefix block.
	xorl    %ecx, %ecx
	movl    12(%esp), %eax
	movl    8(%esp), %edi
	movb    $16, %cl
.Lshabal_init_loop1:
	stosl
	incl    %eax
	loop    .Lshabal_init_loop1
	# Save %eax (it will be used for second prefix block).
	pushl   %eax
	# Set ptr and state[44] to zero.
	xorl    %eax, %eax
	movb    $45, %cl
	rep stosl
	# Set W to -1.
	notl    %eax
	stosl
	stosl
	# Save output size in structure.
	movl    16(%esp), %eax
	stosl
	# Call inner function (registers may be altered).
	pushl   12(%esp)
	call    shabal_inner
	popl    %eax                   # Dummy (remove argument).
	popl    %eax                   # Recover saved counter.

	# Prepare buffer with second prefix block.
	xorl    %ecx, %ecx
	movb    $16, %cl
	movl    8(%esp), %edi
.Lshabal_init_loop2:
	stosl
	incl    %eax
	loop    .Lshabal_init_loop2
	# Increment W; at that point %edi points to structure offset 64.
	leal    180(%edi), %edi
	xorl    %eax, %eax
	stosl
	stosl
	# Call inner function (registers may be altered).
	pushl   8(%esp)
	call    shabal_inner
	popl    %eax
	# Increment W.
	movb    $1, -8(%edi)
	popl    %edi
	ret
	.size	shabal_init, .-shabal_init

.globl shabal
	.type	shabal, @function
shabal:
	# Arguments:
	#   sc     pointer to shabal_context   -> %ebp
	#   data   pointer to data
	#   len    data length (in bytes)

	# We need to backup four registers (%esi, %edi, %ebx and %ebp)
	# which we modify in this function. It is simpler (and uses
	# shorter code) to use the pushal instruction (but it uses
	# 32 more bytes on the stack).
	pushal
	movl    36(%esp), %ebp         # Read sc into %ebp
	movl    40(%esp), %esi         # Read data into %esi
	movl    44(%esp), %edx         # Read len into %edx
	movl    64(%ebp), %ebx         # Read sc->ptr into %ebx
.Lshabal_loop:
	# Main loop entry.
	# If we are at input data end, then exit.
	testl   %edx, %edx
	jnz      .Lshabal_loop2
.Lshabal_exit:
	movl    %ebx, 64(%ebp)
	popal
	ret
.Lshabal_loop2:
	# We have some data to process; we compute the free buffer size
	# in %ecx. That size is between 1 and 64.
	xorl    %ecx, %ecx
	movb    $64, %cl
	subl    %ebx, %ecx
	# We cap %ecx with the actual remaining data length (in %edx).
	cmpl    %edx, %ecx
	jb      .Lshabal_loop3
	movl    %edx, %ecx
.Lshabal_loop3:
	# We copy the data into the buffer; also, we adjust %ebx (the
	# 'ptr' variable) and %edx (remaining data length).
	leal    (%ebp,%ebx), %edi
	addl    %ecx, %ebx
	subl    %ecx, %edx
	# We try to copy data by 4-byte chunks first. The remaining data
	# (0 to 3 bytes), if any, is handled with a 'rep movsb'.
	pushl   %ecx
	shrl    $2, %ecx
	jz      .Lshabal_loop4
	rep     movsl
.Lshabal_loop4:
	popl    %ecx
	andl    $3, %ecx
	jz      .Lshabal_loop5
	rep     movsb
.Lshabal_loop5:
	# If we have not reached the buffer end, then we are finished
	# (all data has necessarily been processed).
	cmpl    $64, %ebx
	jne     .Lshabal_exit
	# We have a full buffer, call shabal_inner() to handle it.
	pushl   %edx
	pushl   %ebp
	call    shabal_inner
	popl    %eax
	popl    %edx
	xorl    %ebx, %ebx             # Buffer is empty.
	# Increment the counter, and loop
	leal    124(%ebp), %ecx
	incl    120(%ecx)
	jnz     .Lshabal_loop
	incl    124(%ecx)
	jmp     .Lshabal_loop
	.size	shabal, .-shabal
