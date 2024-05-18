srcreg:		equr a2
destreg:	equr a1

; -------------------------------------------------------------------------
; Unrolled loop to perform a mass copy of up to 1 kilobyte of data via
; longword moves. Can be called for any amount of data between 4 and 1024
; bytes by placing the number of bytes after "MassCopy_";
;  e.g., "jsr MassCopy_128)".

; If the data size is larger than 1 KB or is not divisible by a longword,
; use the "MassCopy" subroutine below.

; input:
;	srcreg.l = source
;	destreg.l = destination
; -------------------------------------------------------------------------

genmasscopy:	macro

		lblnum:	equs "\#c"				; number used in label

MassCopy_\lblnum:
		move.l	(srcreg)+,(destreg)+
		c: = c-4					; decrement label number
		endm

		c: = 1024

		rept c/4
		genmasscopy
		endr

MassCopy_Base:	; used for dynamic calls into the above
MassCopy_Done:
		rts

; -------------------------------------------------------------------------
; Subroutine to perform a mass copy of up to $3FFFF of data.
; Sets ups/manages calls to the unrolled loop, automatically switching to
; byte moves if one or both of source or destination are odd, and dealing
; with any remainder if longword moves are used.

; input:
;	srcreg.l = source
;	destreg.l = destination
;	d0.l = size of data to copy in bytes

; uses d3.w, d4.l, d5.l
; -------------------------------------------------------------------------

MassCopy:
		tst.l	d0
		beq.s	MassCopy_Done				; exit if size is 0

		move.l	srcreg,d4
		move.l	destreg,d5
		sub.l	d4,d5
		bpl.s	.positive
		neg.l	d5

	.positive:
		cmpi.l	#4,d5				; d5 = difference between source and destination addresses
		bcs.w	MassCopy_Byte		; fall back to bytes if less than 4 (a possibility with RLE compression algorithms)

		move.w	destreg,d5
		moveq	#1,d3					; faster and smaller than using two 'andi #1's
		and.w	d3,d4					; d4 = 0 if source is even; 1 if odd
		and.w	d3,d5					; d5 = same as above, but for destination
		eor.w	d4,d5					; are source and destination both even or both odd?
		bne.w	MassCopy_Byte				; branch if not (fall back to bytes)

		tst.b	d4					; are source and destination even?
		beq.s	.even					; branch if so

		move.b	(srcreg)+,(destreg)+			; copy one byte to align source and destination to even
		subq.l	#1,d0					; minus 1 byte copied

	.even:
		move.l	d0,d5					; back up total size for later
		lsr.l	#2,d0					; d0 = total count of longwords to copy (divide total bytes by four)
		beq.w	MassCopy_FinishBytes			; branch if fewer than 4 bytes total

		move.w	d0,d4					; back up total longwords for later
		lsr.w	#8,d0					; d0 = count of whole kilobytes (divide total longwords by 256)
		beq.s	.less_than_1kb				; branch if less than 1 kilobyte total
		subq.w	#1,d0					; adjust for loop counter

	.longwordloop:
		bsr.w	MassCopy_1024				; copy 1 kilobyte
		dbf	d0,.longwordloop			; repeat for all whole kilobytes

		andi.w	#$FF,d4					; d4 = remaining longwords to copy
		beq.s	.nolongremainder			; branch if 0 (0-4 bytes leftover)

	.less_than_1kb:
		neg.w	d4					; invert remaining longword count
		add.w	d4,d4					; multiply by 2 (size of 'move.l (srcreg)+,(destreg)+') to make index
		jsr	MassCopy_Base(pc,d4.w)			; jump to appropriate location in unrolled loop to copy remaining longwords

	.nolongremainder:
		andi.l	#3,d5					; d5 = remainder if data size was not divisible by a longword
		bne.w	MassCopy_FinishBytes			; do any leftover bytes if necessary
		rts

; -------------------------------------------------------------------------
; Unrolled loop to perform a mass copy of up to 512 bytes of data via
; byte moves. While this can be used the same way as the MassCopy loop, it
; is recommended to call MassCopy instead as that will automatically
; optimize the operation to longword moves if the source and destination
; addresses are even. You MUST use MassCopy if you have more than 512 bytes
; to copy.

; input:
;	srcreg.l = source
;	destreg.l = destination
; -------------------------------------------------------------------------

genmasscopyb:	macro

		lblnum:	equs "\#c"				; number used in label

MassCopyByte_\lblnum\:
		move.b	(srcreg)+,(destreg)+
		c: = c-1					; decrement label number
		endm

		c: = 512

		rept c
		genmasscopyb
		endr

MassCopyByte_Base:						; used for dynamic calls into the above
MassCopyByte_Done:
		rts

; -------------------------------------------------------------------------
; Similar to MassCopy, expect byte-length moves are used

; uses d1.l, d4.l, d5.l
; -------------------------------------------------------------------------

MassCopy_Byte:
		move.l	d0,d5					; back up total byte count for later
		beq.s	MassCopyByte_Done			; exit if size is 0
		moveq	#9,d1					; shift by 9 to divide by 512
		lsr.l	d1,d0					; d0 = count of half-kilobytes (512 bytes)
		beq.s	MassCopy_FinishBytes			; branch if fewer than 512 bytes

		subq.w	#1,d0					; adjust for loop counter

	.loop512:
		bsr.w	MassCopyByte_512			; copy 512 bytes
		dbf	d0,.loop512				; repeat for all half-kilobytes

		andi.l	#$FF,d5					; d5 = count of remaining bytes
		beq.s	MassCopyByte_Done			; branch if no remainder

MassCopy_FinishBytes:
		neg.w	d5					; invert count of remaining bytes
		add.w	d5,d5					; multiply by 2 (size of 'move.b (srcreg)+,(destreg)+') to make index
		jmp	MassCopyByte_Base(pc,d5.w)		; jump to appropriate location in unrolled loop to copy remaining bytes

