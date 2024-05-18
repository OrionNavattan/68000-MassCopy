# 68000 MassCopy

 Unrolled-loop mass copy library for 68000-based platforms, targeting the ASM68K and Macro Assembler AS assemblers.
Supports up to $3FFFF bytes, with no restrictions on alignment or location.

This library combines a pair of unrolled loops, one copying $400 (1024) bytes via longword moves, 
the other $200 (512) bytes via byte moves, with a couple of routines to manage copying arbitrary amounts of data.
In order to speed up the process, the code will favor longword moves for the operation, only falling back to byte moves
if the source and destination addresses cannot be aligned to even (if both are odd aligned, a single byte will be copied to align to even).
To allow more flexibility of use, the unrolled loops have labels within them to enable direct calls into the loops themselves for
data copies with fixed amounts (see usage examples below). For ease of customization, register equates are used for the source 
and destination address registers.

## Usage examples

The following show a couple different ways the library can be used. Note that for small amounts, this routine will be slower than using
a dbf loop, though gains may be realized nonetheless from odd source and destinations being shifted to even.

#### Copying dictionary matches in MDComp Kosinski Decompressor (a2 = copy source, a1 = copy destination)

```
	; Short matches
.streamcopy:
	adda.w	d5,a2		; a2 = start of match
	addq.b	#2,d4		; d4 = actual size of data, no more than 5 bytes
	moveq	#0,d5
	move.b	d4,d5
	jsr MassCopy_FinishBytes	; use value in d5 to make direct jump into byte copy loop
	bra.w	.fetchnewcode
; =============================

	; Long matches
	move.b	(a0)+,d4				; d4 - count
	beq.s	.quit					; if 0, we are done
	cmpi.b	#1,d4
	beq.w	.fetchnewcode			; if 1, fetch a new code.

	adda.w	d5,a2					; a2 = start of match
	addq.w	#1,d4					; d4 = actual size of data to copy
		
	movem.l	d0/d1/d3,-(sp)				; back up descriptor fields and switch flag
	move.w	d4,d0
	jsr MassCopy
	movem.l	(sp)+,d0/d1/d3
	bra.w	.fetchnewcode
```


#### Copying a rendered Sega CD GFX of 22 KB ($5800 bytes) (a0 = source, a1 = destination)

```
.copyrender:
	lea (v_rendered_frame).l,a0	; Sega CD wordram
	lea (v_frame_buffer).w,a1	; Genesis workram
	
	rept	$5800/$400
	jsr	MassCopy_1024	; call the full loop 22 times
	endr
		
```

