# Implementation of Shabal: amd64 (64-bit x86).
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

	.file   "shabal_tiny_amd64.s"
	.text

	.type   shabal_inner, @function
shabal_inner:
	# Arguments:
	#   %rdi   pointer to shabal_context

	# We reserve a 256-byte area to hold the 64 intermediate B words.
	# This allows for faster and smaller access to those words from
	# the main loop; it also simplifies the final B/C swap.
	enter   $256, $0
	pushq   %rbx

	# The intermediate B words are in the stack-based array allocated
	# above; we call it Bx[]. At that point, the buffer low address
	# is equal to %rsp+8, and its high address is %rbp-8

	# Add message words to B; also rotate B words by 17 bits and
	# write the new B words in the Bx[] array.
	# Note:
	#   %rsi   pointer to current data word
	#   %rdi   pointer to the location of the new B word (in Bx[])
	xorl    %ecx, %ecx
	movb    $16, %cl
	pushq   %rdi
	popq    %rsi
	leaq    8(%rsp), %rdi          # Address of Bx[0].
.Lshabal_inner_loop1:
	lodsl                          # Load M word.
	addl    116(%rsi), %eax        # Get B word and add to M word.
	roll    $17, %eax              # Rotate new B word.
	decl    %ecx                   # Decrement loop counter.
	stosl                          # Store new B word.
	jnz     .Lshabal_inner_loop1

	# Xor counter W to A[0]/A[1]; at that point, %rsi points to
	# offset 64 in the context structure.
	movq    184(%rsi), %rax        # Read W counter.
	xorq    %rax, 8(%rsi)          # Xor W into A[0]/A[1].

	# Main loop: 48 iterations
	#   %ebx   previously modified A word ('ap')
	#   %rsi   pointer to A[0]
	#   %rdi   pointer to new value of B, in Bx[]
	#   %rdx   counter for A words (0 to 11, four times)
	#   %rcx counts down from 48 downto 1
	movb    $48, %cl
	movl    52(%rsi), %ebx
	leaq    8(%rsi), %rsi
	xorl    %edx, %edx
.Lshabal_inner_loop2:
	roll    $15, %ebx              # Rotate previous A word by 15 bits.
	pushq   %rcx                   # Save counter.
	leal    (%rbx,%rbx,4), %ebx    # Multiply rotated A word by 5.
	addl    $8, %ecx               # Compute index for C word (part 1).
	xorl    (%rsi,%rdx,4), %ebx    # Get old A word, xor it.
	andl    $15, %ecx              # Compute index for C word (part 2).
	xorl    112(%rsi,%rcx,4), %ebx # Get C word, xor it.
	negl    %ecx                   # Reverse counter for M index
	leal    (%rbx,%rbx,2), %ebx    # Mutiply current value by 3.
	movl    -40(%rdi), %eax        # Get B(u+6).
	addl    $8, %ecx               # Compute index for M word (part 1).
	xorl    -12(%rdi), %ebx        # Get B(u+13), xor it with current.
	notl    %eax                   # Invert B(u+6).
	andl    $15, %ecx              # Compute index for M word (part 2).
	andl    -28(%rdi), %eax        # Get B(u+9), combine with ~B(u+6).
	xorl    %eax, %ebx             # Xor (B(u+9) & ~B(u+6)) with current.
	movl    -64(%rdi), %eax        # Get B(u).
	xorl    -72(%rsi,%rcx,4), %ebx # Get M(u), xor it with current.
	notl    %eax                   # Invert B(u).
	popq    %rcx                   # Recover loop counter.
	roll    $1, %eax               # Rotate ~B(u) by 1 bit.
	decl    %ecx                   # Decrement loop counter.
	xorl    %ebx, %eax             # Xor new A word with rotated ~B(u).
	movl    %ebx, (%rsi,%rdx,4)    # Store new A word.
	incl    %edx                   # Adjust counter for A.
	stosl                          # Store new B word.
	cmpl    $12, %edx
	jne     .Lshabal_inner_loop2
	xorl    %edx, %edx
	testl   %ecx, %ecx             # %ecx can be 0 only if %edx = 0
	jnz     .Lshabal_inner_loop2

	# Secondary loop: add three C words to each A word.
	#   %rsi   points to A[0]
	#   %rdx   counter into A[] (+1, not scaled)
	#   %rcx   loop meta-counter, 3 downto 1 (inclusive)
	movb    $12, %dl
	xorl    %eax, %eax
	movb    $6, %al
	movb    $3, %cl
.Lshabal_inner_loop3:
	movl    112(%rsi,%rax,4), %ebx
	decl    %eax
	addl    %ebx, -4(%rsi,%rdx,4)
	andl    $15, %eax
	decl    %edx
	jnz     .Lshabal_inner_loop3
	decl    %ecx
	movb    $12, %dl
	jnz     .Lshabal_inner_loop3

	# Subtract M words from C words, storing results in B. The "true"
	# B words are in Bx[], so we can handle them afterwards. At
	# that point, %rsi points to A[0].
	#   %rsi   pointer to current M word
	#   %rdi   pointer to emplacement for new C word (in B[])
	movb    $16, %cl
	leaq    48(%rsi), %rdi
	leaq    -72(%rsi), %rsi
.Lshabal_inner_loop4:
	lodsl                          # Load next M word into %eax.
	negl    %eax                   # Compute -M.
	addl    64(%rdi), %eax         # Load next C word, add it to -M.
	decl    %ecx
	stosl                          # Store result in B.
	jnz     .Lshabal_inner_loop4

	# Now we must copy the B words (those on top of Bx[]) into C.
	# At that point, %rdi already points to C[0]. The first B word
	# is Bx[48], located from %ebp (which points at the virtual Bx[64]).
	# Note: we could use 'rep movsl' which is one byte shorter, but
	# (very slightly) slower.
	leaq    -64(%rbp), %rsi
	movb    $8, %cl
	rep movsq

	popq    %rbx
	leave
	ret
	.size   shabal_inner, .-shabal_inner

.globl shabal_close
	.type   shabal_close, @function
shabal_close:
	# Arguments:
	#   %rdi   pointer to shabal_context
	#   %esi   ub
	#   %edx   n
	#   %rcx   dst

	# Compute '0x80 >> n' into %eax.
	xorl    %eax, %eax
	movb    $128, %al
	pushq   %rcx
	movl    %edx, %ecx
	shrl    %cl, %eax
	# Compute extra byte into %al.
	orl     %eax, %esi
	negl    %eax
	andl    %esi, %eax
	# Adjust %rdi to point at the right offset in data buffer.
	# Note: we read 'ptr' into %rdx; thus, %rdx value lies in 0..63.
	# We just need to read the low 32 bits (the processor zero-extends
	# the value in the register).
	pushq   %rdi
	movl    64(%rdi), %edx
	addq    %rdx, %rdi
	# Write last data / first padding byte.
	stosb
	# Append some zero bytes to complete buffer. We set %ecx but the
	# processor zero-extends the upper 32 bits.
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
.Lshabal_close_loop:
	# Since some registers are not preserved by the call, we need
	# to save them. We also need to set %rdi before each call
	# (parameter to shabal_inner()).
	popq    %rdi
	pushq   %rdi
	pushq   %rcx
	call    shabal_inner
	popq    %rcx
	loop    .Lshabal_close_loop

	# Hash result is in the 'C' variables.
	# We recover context address and destination address from stack.
	popq    %rsi
	popq    %rdi
	# Get the output size in bits, convert it to a number of 32-bit
	# words.
	movl    256(%rsi), %ecx
	shrl    $5, %ecx
	# Compute start offset in C.
	# At that point, %rdx contains a very small value (0 to 63) and
	# the output size is in %rcx, expressed in 32-bit words (hence
	# in the 1..16 range). We want to add 248-4*%rcx to %rsi without
	# modifying %rcx.
	xorl    %edx, %edx
	movb    $62, %dl
	subl    %ecx, %edx
	leaq    (%rsi,%rdx,4), %rsi
	# Copy hash result and return.
	rep movsl
	ret
	.size   shabal_close, .-shabal_close

.globl shabal_init
	.type   shabal_init, @function
shabal_init:
	# Arguments:
	#   %rdi   pointer to shabal_context
	#   %rsi   output size (in bits)

	pushq   %rdi
	# Initialize buffer with first prefix block.
	xorl    %ecx, %ecx
	movl    %esi, %eax
	movb    $16, %cl
.Lshabal_init_loop1:
	stosl
	incl    %eax
	loop    .Lshabal_init_loop1
	# Save %rax (it will be used for second prefix block).
	pushq   %rax
	# Set ptr and state[44] to zero.
	xorl    %eax, %eax
	movb    $46, %cl
	rep stosl
	# Set W to -1.
	notl    %eax
	stosl
	stosl
	# Save output size in structure.
	movl    %esi, %eax
	stosl
	# Call inner function (registers may be altered). We
	# need to set %rdi (parameter to shabal_inner()); the
	# pop/pop/push/push sequence is the shortest way to do that.
	popq    %rax
	popq    %rdi
	pushq   %rdi
	pushq   %rax
	call    shabal_inner

	# Prepare buffer with second prefix block. We recover our
	# saved 32-bit value (which is equal to out_size+16 at that point).
	xorl    %ecx, %ecx
	movb    $16, %cl
	popq    %rax
	popq    %rdi
	pushq   %rdi
.Lshabal_init_loop2:
	stosl
	incl    %eax
	loop    .Lshabal_init_loop2
	# Increment W; at that point %rdi points to structure offset 64.
	leaq    184(%rdi), %rsi
	incq    (%rsi)
	# Call inner function (registers may be altered).
	popq    %rdi
	pushq   %rsi
	call    shabal_inner
	# Increment W.
	popq    %rsi
	incq    (%rsi)
	ret
	.size   shabal_init, .-shabal_init

.globl shabal
	.type   shabal, @function
shabal:
	# Arguments:
	#   %rdi   pointer to shabal_context   -> %rbp
	#   %rsi   pointer to data
	#   %rdx   data length (in bytes)
	#
	#   %rbx is used to hold sc->ptr
	pushq   %rbp
	pushq   %rbx
	pushq   %rdi
	popq    %rbp
	# 'ptr' is always small, so we can just read the low 32 bits.
	movl    64(%rdi), %ebx
.Lshabal_loop:
	# Main loop entry.
	# If we are at input data end, then exit.
	testq   %rdx, %rdx
	jnz      .Lshabal_loop2
.Lshabal_exit:
	movl    %ebx, 64(%rbp)
	popq    %rbx
	popq    %rbp
	ret
.Lshabal_loop2:
	# We have some data to process; we compute the free buffer size
	# in %rcx. That size is between 1 and 64. Note: we just set the
	# low 32 bits, but the processor clears the upper 32 bits of %rcx.
	xorl    %ecx, %ecx
	movb    $64, %cl
	subl    %ebx, %ecx
	# We cap %rcx with the actual remaining data length (in %rdx).
	# Note: if %rcx > %rdx then %rdx is small, hence we can use %edx.
	cmpq    %rdx, %rcx
	cmova   %edx, %ecx
	# We copy the data into the buffer; also, we adjust %rbx (the
	# 'ptr' variable) and %rdx (remaining data length).
	leaq    (%rbp,%rbx), %rdi
	addl    %ecx, %ebx
	subq    %rcx, %rdx
	# We first try to copy data by 8-byte chunks. We then revert to a
	# 'rep movsb' for the remaining bytes, if any.
	pushq   %rcx
	shrl    $3, %ecx
	jz      .Lshabal_loop3
	rep     movsq
.Lshabal_loop3:
	popq    %rcx
	andl    $7, %ecx
	jz      .Lshabal_loop4
	rep movsb
.Lshabal_loop4:
	# If we have not reached the buffer end, then we are finished
	# (all data has necessarily been processed).
	cmpl    $64, %ebx
	jne     .Lshabal_exit
	# We have a full buffer, call shabal_inner() to handle it.
	pushq   %rdx
	pushq   %rsi
	pushq   %rbp
	popq    %rdi
	call    shabal_inner
	# Increment the counter, reset 'ptr' (%rbx) to 0, and loop
	incq    248(%rbp)
	popq    %rsi
	popq    %rdx
	xorl    %ebx, %ebx
	jmp     .Lshabal_loop
	.size   shabal, .-shabal
