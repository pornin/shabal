; Implementation of Shabal: AVR, 8-bit.
;
; This code follows the calling convention used by AVR-GCC. It should
; compile and run on most of current Atmel AVR8-based MCU, including
; those which use the "classic core" with the MOVW additional opcode,
; and all those using the "enhanced core".
;
; -----------------------------------------------------------------------
; (c) 2010 SAPHIR project. This software is provided 'as-is', without
; any epxress or implied warranty. In no event will the authors be held
; liable for any damages arising from the use of this software.
;
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to no restriction.
;
; Technical remarks and questions can be addressed to:
; <thomas.pornin@cryptolog.com>
; -----------------------------------------------------------------------

	.file	"shabal_tiny_avr8.s"
__SREG__ = 0x3F
__SP_H__ = 0x3E
__SP_L__ = 0x3D
__CCP__  = 0x34
__tmp_reg__ = 0
__zero_reg__ = 1
	.global __do_copy_data
	.global __do_clear_bss
	.text
; --------------------------------------------------------------------
; reduced_memcpy() is a reduced version of the memcpy() function:
;   Z     source pointer (updated)
;   X     destination pointer (updated)
;   r20   copy length (MUST NOT be zero; only one byte)
;
	.type   reduced_memcpy, @function
reduced_memcpy:
	ld      __tmp_reg__, Z+
	st      X+, __tmp_reg__
	dec     r20
	brne    reduced_memcpy
	ret
	.size   reduced_memcpy, .-reduced_memcpy

; --------------------------------------------------------------------
; shabal_inner(sc)
;    sc   pointer to context structure
;
; This function actually expects its argument in r2:3, not r24:25.
;
	.type   shabal_inner, @function
shabal_inner:
	push    r6
	push    r7
	push    r8
	push    r9
	push    r16
	push    r17
	push    r28
	push    r29

	; In this function, we call U the 32-bit value in r18-r21,
	; while r22-r25 is called V.

	; ------------------------------------------------------------
	; First loop: add M to B, rotate B.

	; X     pointer to M
	; Z     pointer to B
	; r16   loop counter
	; Note: we save &B[0] in r6:7
	movw    r26, r2
	movw    r30, r2
	subi    r30, lo8(-114)
	sbci    r31, hi8(-114)
	movw    r6, r30
	ldi     r16, 16
.L0m:
	; Load M word into U.
	ld      r18, X+
	ld      r19, X+
	ld      r20, X+
	ld      r21, X+

	; Load B word into v.
	ld      r22, Z
	ldd     r23, Z+1
	ldd     r24, Z+2
	ldd     r25, Z+3

	; Add V to U.
	add     r18, r22
	adc     r19, r23
	adc     r20, r24
	adc     r21, r25

	; Rotate U (1+16 bits) and store back as new B word.
	lsl     r18
	rol     r19
	rol     r20
	rol     r21
	adc     r18, __zero_reg__
	st      Z+, r20
	st      Z+, r21
	st      Z+, r18
	st      Z+, r19

	; Loop 16 times.
	dec     r16
	brne    .L0m

	; ------------------------------------------------------------
	; Xor W into A.

	; At that point, X points to the ptr field, and Z to C[0].
	; X     pointer to A byte
	; Z     pointer to W byte
	; r16   loop counter
	; Note: we save &C[0] to r8:9 and &A[0] to r24:25
	adiw    r26, 2
	movw    r24, r26
	movw    r8, r30
	subi    r30, lo8(-64)
	sbci    r31, hi8(-64)
	ldi     r16, 8
.L1m:
	ld      r18, X                 ; Load byte from A.
	ld      r19, Z+                ; Load byte from W, update Z.
	eor     r18, r19               ; Xor bytes from A and W.
	st      X+, r18                ; Store byte into A, update X.
	dec     r16
	brne    .L1m

	; ------------------------------------------------------------
	; Main loop (48 iterations).

	; U     previous/current A word
	; Z     pointer to current A word
	; r16   main loop counter, 192 downto 0, -4 increments
	; r17   secondary counter, 12 downto 0, 4x
	movw    r30, r24
	ldd     r18, Z+44
	ldd     r19, Z+45
	ldd     r20, Z+46
	ldd     r21, Z+47
	ldi     r16, 192
	ldi     r17, 12
.L2m:
	; Rotate U right by 1 bit.
	mov     __tmp_reg__, r18
	ror     __tmp_reg__
	ror     r21
	ror     r20
	ror     r19
	ror     r18

	; Rotate U left by 16 bits, and copy it into V.
	movw    r24, r18
	movw    r22, r20
	movw    r18, r22
	movw    r20, r24

	; Multiply V by 4.
	lsl     r22
	rol     r23
	rol     r24
	rol     r25
	lsl     r22
	rol     r23
	rol     r24
	rol     r25

	; Add V to U.
	add     r18, r22
	adc     r19, r23
	adc     r20, r24
	adc     r21, r25

	; Load A word and xor it to U.
	ld      __tmp_reg__, Z
	eor     r18, __tmp_reg__
	ldd     __tmp_reg__, Z+1
	eor     r19, __tmp_reg__
	ldd     __tmp_reg__, Z+2
	eor     r20, __tmp_reg__
	ldd     __tmp_reg__, Z+3
	eor     r21, __tmp_reg__

	; Compute C word index.
	ldi     r25, 32
	add     r25, r16
	andi    r25, 60

	; Load C word and xor it to U. &C[0] is in r8:9.
	movw    r26, r8
	add     r26, r25
	adc     r27, __zero_reg__
	ld      __tmp_reg__, X+
	eor     r18, __tmp_reg__
	ld      __tmp_reg__, X+
	eor     r19, __tmp_reg__
	ld      __tmp_reg__, X+
	eor     r20, __tmp_reg__
	ld      __tmp_reg__, X
	eor     r21, __tmp_reg__

	; Copy U into V.
	movw    r22, r18
	movw    r24, r20

	; Multiply V by 2.
	lsl     r22
	rol     r23
	rol     r24
	rol     r25

	; Add V to U.
	add     r18, r22
	adc     r19, r23
	adc     r20, r24
	adc     r21, r25

	; Compute B first access index (u+13) into r25.
	ldi     r25, 244
	sub     r25, r16
	andi    r25, 60

	; Load B[u + 13] and xor it into U.
	movw    r26, r6
	add     r26, r25
	adc     r27, __zero_reg__
	ld      __tmp_reg__, X+
	eor     r18, __tmp_reg__
	ld      __tmp_reg__, X+
	eor     r19, __tmp_reg__
	ld      __tmp_reg__, X+
	eor     r20, __tmp_reg__
	ld      __tmp_reg__, X
	eor     r21, __tmp_reg__

	; Load B[u + 9] and B[u + 6], xor (B[u + 9] & ~B[u + 6]) into U.
	subi    r25, 16
	andi    r25, 60
	movw    r26, r6
	add     r26, r25
	adc     r27, __zero_reg__
	subi    r25, 12
	andi    r25, 60
	movw    r28, r6
	add     r28, r25
	adc     r29, __zero_reg__

	ld      r22, X+
	ld      r23, Y+
	com     r23
	and     r22, r23
	eor     r18, r22
	ld      r22, X+
	ld      r23, Y+
	com     r23
	and     r22, r23
	eor     r19, r22
	ld      r22, X+
	ld      r23, Y+
	com     r23
	and     r22, r23
	eor     r20, r22
	ld      r22, X
	ld      r23, Y
	com     r23
	and     r22, r23
	eor     r21, r22

	; Load M[u] and xor it into U.
	subi    r25, 24
	andi    r25, 60
	movw    r26, r2
	add     r26, r25
	adc     r27, __zero_reg__
	ld      __tmp_reg__, X+
	eor     r18, __tmp_reg__
	ld      __tmp_reg__, X+
	eor     r19, __tmp_reg__
	ld      __tmp_reg__, X+
	eor     r20, __tmp_reg__
	ld      __tmp_reg__, X
	eor     r21, __tmp_reg__

	; Store new value of A (currently in U).
	st      Z+, r18
	st      Z+, r19
	st      Z+, r20
	st      Z+, r21

	; Load B[u] into V.
	movw    r28, r6
	add     r28, r25
	adc     r29, __zero_reg__
	ld      r22, Y
	ldd     r23, Y+1
	ldd     r24, Y+2
	ldd     r25, Y+3

	; Compute rotl(B[u], 1).
	lsl     r22
	rol     r23
	rol     r24
	rol     r25
	adc     r22, __zero_reg__

	; Xor ~rotl(B[u], 1) with U and store it back in B[u].
	com     r22
	eor     r22, r18
	st      Y+, r22
	com     r23
	eor     r23, r19
	st      Y+, r23
	com     r24
	eor     r24, r20
	st      Y+, r24
	com     r25
	eor     r25, r21
	st      Y, r25

	; Decrement loop counters.
	subi    r16, 4
	dec     r17
	brne    .L2m_indirect          ; Loop 12 times (x4).

	; Reset Z to &A[0].
	subi    r30, 48
	sbci    r31, 0

	; Reset secondary counter to 12, and loop (4 times).
	ldi     r17, 12
	tst     r16
	breq    .L2m_exit
.L2m_indirect:
	rjmp    .L2m
.L2m_exit:

	; ------------------------------------------------------------
	; Third loop: add C words to A words.

	; Z     points to current A word (already set)
	; r16   loop counter (12 downto 1)
	; r25   index for C words, begins at 12
	ldi     r16, 12
	ldi     r25, 12
.L4m:
	; Load next A word into U.
	ld      r18, Z
	ldd     r19, Z+1
	ldd     r20, Z+2
	ldd     r21, Z+3

	; Load third C word, add it; index is computed into r25.
	movw    r26, r8
	add     r26, r25
	adc     r27, __zero_reg__
	ld      __tmp_reg__, X+
	add     r18, __tmp_reg__
	ld      __tmp_reg__, X+
	adc     r19, __tmp_reg__
	ld      __tmp_reg__, X+
	adc     r20, __tmp_reg__
	ld      __tmp_reg__, X
	adc     r21, __tmp_reg__

	; Load first C word, add it.
	subi    r25, lo8(-32)
	andi    r25, 60
	movw    r26, r8
	add     r26, r25
	adc     r27, __zero_reg__
	ld      __tmp_reg__, X+
	add     r18, __tmp_reg__
	ld      __tmp_reg__, X+
	adc     r19, __tmp_reg__
	ld      __tmp_reg__, X+
	adc     r20, __tmp_reg__
	ld      __tmp_reg__, X
	adc     r21, __tmp_reg__

	; Load second C word, add it.
	subi    r25, lo8(-16)
	andi    r25, 60
	movw    r26, r8
	add     r26, r25
	adc     r27, __zero_reg__
	ld      __tmp_reg__, X+
	add     r18, __tmp_reg__
	ld      __tmp_reg__, X+
	adc     r19, __tmp_reg__
	ld      __tmp_reg__, X+
	adc     r20, __tmp_reg__
	ld      __tmp_reg__, X
	adc     r21, __tmp_reg__

	; Store new A word.
	st      Z+, r18
	st      Z+, r19
	st      Z+, r20
	st      Z+, r21

	; Prepare C index for next loop.
	subi    r25, lo8(-20)
	andi    r25, 60

	; Decrement counter and loop (12 times).
	dec     r16
	brne    .L4m

	; ------------------------------------------------------------
	; Fourth loop: subtract M from C, swap B and C.

	; X     pointer to M word
	; Y     pointer to C word
	; Z     pointer to B word
	; r16   loop counter
	movw    r26, r2
	movw    r28, r8
	movw    r30, r6
	ldi     r16, 16
.L5m:
	; Load C word into U.
	ld      r18, Y
	ldd     r19, Y+1
	ldd     r20, Y+2
	ldd     r21, Y+3

	; Load M word into V.
	ld      r22, X+
	ld      r23, X+
	ld      r24, X+
	ld      r25, X+

	; Subtract V from U.
	sub     r18, r22
	sbc     r19, r23
	sbc     r20, r24
	sbc     r21, r25

	; Load B word into V.
	ld      r22, Z
	ldd     r23, Z+1
	ldd     r24, Z+2
	ldd     r25, Z+3

	; Store new B word (from U).
	st      Z+, r18
	st      Z+, r19
	st      Z+, r20
	st      Z+, r21

	; Store new C word (from V).
	st      Y+, r22
	st      Y+, r23
	st      Y+, r24
	st      Y+, r25

	; Decrement counter, loop (16 times).
	dec     r16
	brne    .L5m

	; ------------------------------------------------------------
	; Return from function.

	pop     r29
	pop     r28
	pop     r17
	pop     r16
	pop     r9
	pop     r8
	pop     r7
	pop     r6
	ret
	.size   shabal_inner, .-shabal_inner

; --------------------------------------------------------------------
; shabal_close(sc, ub, n, dst)
;    sc    pointer to context structure
;    ub    extra bits
;    n     number of extra bits
;    dst   destination buffer
;
	.global shabal_close
	.type   shabal_close, @function
shabal_close:
	push    r2
	push    r3
	push    r4
	push    r5

	; sc    r2:3
	; dst   r4:5
	movw    r2, r24
	movw    r4, r18

	; Compute z = 0x80 >> n.
	ldi     r18, 0x80
	inc     r20
.L0c:
	dec     r20
	breq    .L1c
	lsr     r18
	rjmp    .L0c

.L1c:
	or      r22, r18               ; Compute (ub | z).
	neg     r18                    ; Compute -z.
	and     r22, r18               ; Compute (ub | z) & (-z).

	movw    r30, r2                ; Load context pointer.
	subi    r30, lo8(-64)          ; Compute pointer to ptr (part 1).
	sbci    r31, hi8(-64)          ; Compute pointer to ptr (part 2).
	ld      r19, Z                 ; Load ptr.

	movw    r26, r2                ; Load context pointer.
	add     r26, r19               ; Compute destination pointer (part 1).
	adc     r27, __zero_reg__      ; Compute destination pointer (part 2).
	st      X+, r22                ; Store extra byte.

	; We fill the buffer end with zeros. We use Z as marker for buffer
	; end. Since X and Z differ by at most 63, we need compare only
	; the low bytes (r26 vs r30). We also overflow by 1 byte, which is
	; harmless (we overflow into the 'ptr' field).
.L2c:
	cp      r26, r30               ; Compare X with Z (low byte only).
	st      X+, __zero_reg__       ; Clear next byte.
	brne    .L2c                   ; Loop until buffer end.

	rcall   shabal_inner           ; Call inner function.
	rcall   shabal_inner           ; Call inner function.
	rcall   shabal_inner           ; Call inner function.
	rcall   shabal_inner           ; Call inner function.

	movw    r30, r2                ; Load context pointer.
	subi    r30, lo8(-242)         ; Compute pointer to W (part 1).
	sbci    r31, hi8(-242)         ; Compute pointer to W (part 2).
	ldd     r20, Z+8               ; Load output size (in bytes).
	sub     r30, r20               ; Compute source pointer (part 1).
	sbc     r31, __zero_reg__      ; Compute source pointer (part 2).
	movw    r26, r4                ; Restore destination pointer.
	rcall   reduced_memcpy         ; Copy output.

	pop     r5
	pop     r4
	pop     r3
	pop     r2
	ret
	.size   shabal_close, .-shabal_close

; set_input_words: routine to set the prefix input words.
; Parameters:
;    r2:3     pointer to input buffer
;    r4:5     current input word (updated)
;
; r18 is destroyed. Z is set to one past the buffer end. r4 is updated.
;
	.type   set_input_words, @function
set_input_words:
	ldi     r18, 16                ; Set loop counter.
	movw    r30, r2                ; Set destination pointer.
.L0i:
	st      Z+, r4                 ; Store next input word (byte 0).
	st      Z+, r5                 ; Store next input word (byte 1).
	st      Z+, __zero_reg__       ; Store next input word (byte 2).
	st      Z+, __zero_reg__       ; Store next input word (byte 3).
	inc     r4                     ; Increment input word.
	dec     r18                    ; Decrement loop counter.
	brne    .L0i                   ; Loop 16 times.
	ret
	.size   set_input_words, .-set_input_words

; --------------------------------------------------------------------
; shabal_init(sc, out_size)
;    sc         pointer to context structure
;    out_size   output size (in bits)
;
	.global shabal_init
	.type   shabal_init, @function
shabal_init:
	push    r2
	push    r3
	push    r4
	push    r5

	; sc         r2:3
	; out_size   r4:5 (updated)
	movw    r2, r24
	movw    r4, r22

	rcall   set_input_words        ; Set input words (first prefix block).

	ldi     r18, 178               ; Set loop counter.
.L1i:
	st      Z+, __zero_reg__       ; Clear next byte.
	dec     r18                    ; Decrement loop counter.
	brne    .L1i                   ; Loop 178 times.

	ldi     r18, 8                 ; Set loop counter.
	ldi     r19, 255               ; Set W init bytes.
.L2i:
	st      Z+, r19                ; Set next W byte.
	dec     r18                    ; Decrement loop counter.
	brne    .L2i                   ; Loop 8 times.

	; Convert out_size to bytes instead of bits. We know that the
	; output size is no more than 512.
	lsr     r23
	ror     r22
	lsr     r23
	ror     r22
	lsr     r22
	st      Z, r22                 ; Store out_size (in bytes).

	rcall   shabal_inner           ; Call inner function.

	rcall   set_input_words        ; Set input words (second prefix block).

	subi    r30, lo8(-178)         ; Compute W pointer (part 1).
	sbci    r31, hi8(-178)         ; Compute W pointer (part 2).
	ldi     r18, 8                 ; Set loop counter.
.L3i:
	st      Z+, __zero_reg__       ; Clear next W byte.
	dec     r18                    ; Decrement loop counter.
	brne    .L3i                   ; Loop 8 times.

	rcall   shabal_inner           ; Call inner function.

	movw    r30, r2                ; Restore pointer to context.
	subi    r30, lo8(-242)         ; Compute W pointer (part 1).
	sbci    r31, hi8(-242)         ; Compute W pointer (part 2).
	ldi     r18, 1
	st      Z, r18                 ; Set Wlow to 1.

	pop     r5
	pop     r4
	pop     r3
	pop     r2
	ret
	.size   shabal_init, .-shabal_init

; --------------------------------------------------------------------
; shabal(sc, data, len)
;    sc     pointer to context structure
;    data   pointer to input data
;    len    input data length (in bytes)
;
	.global shabal
	.type   shabal, @function
shabal:
	push    r2
	push    r3
	push    r4
	push    r5
	push    r6
	push    r7
	push    r17

	; sc     r2:r3
	; data   r4:r5
	; len    r6:r7
	; ptr    r17

	movw    r2, r24                ; Save sc in r2:3.
	movw    r4, r22                ; Save data in r4:5.
	movw    r6, r20                ; Save len in r6:7.
	movw    r30, r2                ; Load pointer to context in Z.
	subi    r30, lo8(-64)          ; Compute ptr field address (part 1).
	sbci    r31, hi8(-64)          ; Compute ptr field address (part 2).
	ld      r17, Z                 ; Load ptr field (one byte only).

.L0s:
	cp      r6, __zero_reg__
	cpc     r7, __zero_reg__
	brne    .L2s
.L1s:
	movw    r30, r2                ; Load pointer to context in Z.
	subi    r30, lo8(-64)          ; Compute ptr field address (part 1).
	sbci    r31, hi8(-64)          ; Compute ptr field address (part 2).
	st      Z, r17                 ; Store ptr.
	pop     r17
	pop     r7
	pop     r6
	pop     r5
	pop     r4
	pop     r3
	pop     r2
	ret
.L2s:
	ldi     r20, 64                ; Compute 64-ptr (part 1).
	sub     r20, r17               ; Compute 64-ptr (part 2).
	cp      r7, __zero_reg__       ; If len >= 256 then skip.
	brne    .L3s
	cp      r6, r20                ; If len >= 64-ptr then skip.
	brsh    .L3s
	mov     r20, r6                ; Set r20 = min(64-ptr, len).
.L3s:
	movw    r26, r2                ; Compute destination (part 1).
	add     r26, r17               ; Compute destination (part 2).
	adc     r27, __zero_reg__      ; Compute destination (part 3).
	movw    r30, r4                ; Compute source.
	add     r17, r20               ; Increment ptr.
	add     r4, r20                ; Increment data (part 1).
	adc     r5, __zero_reg__       ; Increment data (part 2).
	sub     r6, r20                ; Decrement len (part 1).
	sbc     r7, __zero_reg__       ; Decrement len (part 2).
	rcall   reduced_memcpy         ; Copy chunk.
	cpi     r17, 64                ; Check if reached buffer end.
	brne    .L1s                   ; If not, then exit.
	rcall   shabal_inner           ; Call inner function.
	clr     r17                    ; Reset ptr.
	movw    r30, r2                ; Load structure pointer.
	subi    r30, lo8(-242)         ; Compute W offset (part 1).
	sbci    r31, hi8(-242)         ; Compute W offset (part 2).
	ldi     r19, 8                 ; Set loop counter.
	sec                            ; Set carry.
.L4s:
	ld      r18, Z                 ; Load next W byte.
	adc     r18, __zero_reg__      ; Increment W byte.
	st      Z+, r18                ; Store updated W byte, update Z.
	dec     r19                    ; Decrement loop counter.
	brne    .L4s                   ; Loop 8 times.
	rjmp    .L0s                   ; Main loop.
	.size   shabal, .-shabal
