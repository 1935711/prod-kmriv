; General Comment:
;
; I use macros to avoid wasting bytes for JMP instructions when some routine
; is used once or is very small. An alternative would be to place them all,
; one after the other inside main but that's messy.

format	binary
org	0x7C00
use16

start:
	jmp	main			; Jump over data

; @note For keeping track/controlling the demo effects
frame		dw 0x0000		; How many frames have been simulated
effect		db 0x00			; To indicate what effects are active now
effect_drunk	= 0x01
effect_rose	= 0x02			; Requires "drunk" effect
effect_galaxy	= 0x04

; @note The seed will hold the latest generated random number
seed		dw 0xAB1C		; Seed which determines the initial condition of all agents
; 0x1935
; 0xABC1
; 0x5711
; 0x1ABC

; @note No need for a large stack hence the small region
stack_mem	= 0x0050		; Size: 30KB (conventional memory)

; @note `phys_addr = (seg_addr * 16) + offset` hence all are missing LSB
vid0_mem	= 0xA000		; Size: 320*200*1 (video display memory)

; @note Video 1 is the trail map. This is done so that any extra elements can be
; written to video 0 and not interfere with the simulation.
vid1_mem	= 0x07E0		; Size: 320*200*1 (conventional memory)

; @note Agent memory is really multiple consecutive segments, each 0xFFFF in size
; @note Each agent is a struct: {uint16_t x; uint16_t y; uint8_t heading} (5 bytes in total)
agnt_mem	= 0x1780		; Size: agnt_cnt*agnt_siz (conventional memory)
agnt_cnt	= 0x2D00		; Number of agents (max 16k)
agnt_siz	= 5			; Size of each agent struct
agnt_off_x	= 0			; Offset where x pos is in agent
agnt_off_y	= 2			; Offset where y pos is in agent
agnt_off_r	= 4			; Offset where rotation is in agent

; @note The list here is the list of offsets for X and Y to reach the whole moore neighborhood.
; Y coords begin at 1st element, X at the 3rd element.
moore_nbhd 	dw -1, -1, -1, 0, 1, 1, 1, 0, -1, -1
moore_nbhd_x	= moore_nbhd + (2 * 2)	; Each element is a WORD so to skip 2 elements, skip 4 bytes
moore_nbhd_y	= moore_nbhd

macro agent_init
{
; @brief Initialize all the agents
	mov	cx, agnt_cnt

	.init_next:
	push	cx

	; DI is offset to agnt[CX]
	mov	ax, cx
	dec	ax
	mov	bx, agnt_siz
	mul	bx
	mov	di, ax

	; Generate random X position.
	call	rand
	mod316
	inc	ax
	inc	ax			; Add 2 for the margin
	mov	WORD [es:di + agnt_off_x], ax

	; Generate random Y position.
	call	rand
	mod196
	inc	ax
	inc	ax			; Add 2 for the margin
	mov	WORD [es:di + agnt_off_y], ax

	; Generate random rotation.
	call	rand
	and	al, 0x07
	mov	BYTE [es:di + agnt_off_r], al

	pop	cx
	loop	.init_next
}

macro agent_sense_and_rotate
{
; @brief Sense concentration of trail ahead and rotate towards the highest concentration
	mov	cx, agnt_cnt

	xor	si, si
	.srm_next:
	push	cx
	push	si			; Save index of agent
	mov	cx, 3			; Iterate for each of the 3 sensors
	.sense_next_off:
	; Get byte offset into neighborhood list into BX
	mov	bx, WORD [es:si + agnt_off_r]
	add	bx, cx
	dec	bx
	rot_to_idx

	; Create Y coordinate with offset
	mov	ax, WORD [es:si + agnt_off_y]
	mov	dx, WORD [moore_nbhd_y + bx]
	add	ax, dx			; AX = agnt.y + offset.y

	; Save Y coordinate
	push	ax

	; Create X coordinate with offset
	mov	ax, WORD [es:si + agnt_off_x]
	mov	dx, WORD [moore_nbhd_x + bx]
	add	ax, dx			; AX = agnt.x + offset.x

	; Restore Y coordinate into BX
	pop	bx			; BX = agnt.y + offset.y

	call	xy_to_idx
	mov	bx, ax
	xor	ax, ax
	mov	al, BYTE [fs:bx]
	push	ax			; Save sensed value

	; Repeat until checked all sensors
	loop	.sense_next_off

	pop	cx			; Left val
	pop	ax			; Center val
	pop	bx			; Right val

	mov	al, BYTE [effect]
	and	al, effect_drunk
	jz	.effect_drunk_end
	.effect_drunk_start:
	xchg	bx, cx			; Flip right and left side
	.effect_drunk_end:
	pop	si			; Restore index of agent
	mov	dl, BYTE [es:si + agnt_off_r] ; Cache current rotation for size

	; Rotate the agent based on sensed values
	; 1. Check which side is largest
	cmp	bx, cx
	jg	.rot_right_g_left
	; 2. Check if center is larger than largest side
	.rot_left_g_right:
	cmp	ax, cx
	jge	.rot_end
	jmp	.rot_left
	.rot_right_g_left:
	cmp	ax, bx
	jge	.rot_end
	.rot_right:
	inc	dl
	jmp	.rot_end
	.rot_left:
	dec	dl
	.rot_end:

	mov	al, BYTE [effect]
	push	ax
	and	al, effect_rose
	jz	.effect_rose_skip
	.effect_rose_apply:
	mov	ax, WORD [frame]
	and	al, 0x01		; Adjust rotation by max 1 point
	add	dl, al
	.effect_rose_skip:
	pop	ax
	and	al, effect_galaxy
	jz	.effect_galaxy_skip
	.effect_galaxy_apply:
	add	dl, 5			; Better than any other (2,3,4,5,6,7)
	.effect_galaxy_skip:

	and	dl, 0x07 ; Ensure rotation is in the allowed range
	mov	BYTE [es:si + agnt_off_r], dl

	add	si, agnt_siz		; Next agent
	pop	cx
	dec	cx
	jnz	.srm_next
}

macro agent_deposit_and_move
{
; @brief Deposit trail on the trail map and move towards orientation
	mov	cx, agnt_cnt

	xor	si, si
	.deposit_next:
	push	cx

	; Deposit
	mov	ax, WORD [es:si + agnt_off_x]
	mov	bx, WORD [es:si + agnt_off_y]
	call	xy_to_idx
	mov	di, ax
	mov	al, 2
	add	BYTE [fs:di], al

	; Move
	mov	bx, WORD [es:si + agnt_off_r]
	rot_to_idx
	mov	ax, WORD [moore_nbhd_x + bx]
	mov	bx, WORD [moore_nbhd_y + bx]
	add	WORD [es:si + agnt_off_x], ax
	add	WORD [es:si + agnt_off_y], bx

	; Ensure agents do not go out of bounds by rotating them at tangent to border.
	; There is a 2 pixel border where nothing shall be drawn.
	mov	ax, WORD [es:si + agnt_off_x]
	cmp	ax, 2
	jg	.x_left_inside
	.x_left_outside:
	mov	BYTE [es:si + agnt_off_r], 3
	.x_left_inside:
	cmp	ax, 318
	jl	.x_right_inside
	.x_right_outside:
	mov	BYTE [es:si + agnt_off_r], 7
	.x_right_inside:
	mov	ax, WORD [es:si + agnt_off_y]
	cmp	ax, 2
	jg	.y_top_inside
	.y_top_outside:
	mov	BYTE [es:si + agnt_off_r], 5
	.y_top_inside:
	cmp	ax, 198
	jl	.y_bottom_inside
	.y_bottom_outside:
	mov	BYTE [es:si + agnt_off_r], 1
	.y_bottom_inside:

	; Rotation here is within limits so no need to AND it with 0x07

	add	si, agnt_siz		; Next agent
	pop	cx
	loop	.deposit_next
}

macro trail_decay
{
; @brief Decrease values in the trail map to simulate slow dissipation over time.
	mov	cx, 320*200		; Each buffer is 320*200 bytes long
	dec	cx

	.decay_next:
	mov	di, cx
	cmp	BYTE [fs:di], 0
	je	.decay_no
	.decay_yes:
	dec	BYTE [fs:di]
	.decay_no:
	loop	.decay_next
}

macro memcpy_vid1to0
{
; @brief Copy vid1 buffer to vid0 buffer
	mov	cx, 320*200		; Each buffer is 320*200 bytes long

	xor	si, si
	.memcpy_next:
	mov	dl, BYTE [fs:si]	; DL = vid1[CX]
	mov	BYTE [gs:si], dl	; vid0_mem[CX] = DL = vid1_mem[CX]

	inc	si			; Copy 2 bytes at a time (32k MOVs in total)
	loop	.memcpy_next
}

macro sleep
{
; @brief Sleep (between frames)
	mov	ah, 0x86
	xor	cx, cx
	mov	dx, 0x2FFF
	int	0x15
}

macro mod316
{
; @brief Get remainder after dividing any number by 316
; @param AX Input number
; @return AX Result (16 bits)
	mov	cx, 316
	xor	dx, dx
	div	cx
	mov	ax, dx
}

macro mod196
{
; @brief Get remainder after dividing any number by 196
; @param AX Input number
; @return AX Result (16 bits)
	mov	cx, 196
	xor	dx, dx
	div	cx
	mov	ax, dx
}

macro rot_to_idx
{
; @brief Convert rotation to an index in the moore neighborhood list
; @param BX Rotation index
; @return BX Rotation byte offset
	and	bx, 0x0007		; BX = Index in neighborhood list (mod 8)
	add	bx, bx			; Each element is 2 bytes. This converts index to byte offset.
	and	bl, 0x0F		; BX = Byte offset in neighborhood list (mod 16)
}

macro vid_mode_g
{
; @brief Set video mode to graphical (13h)
; @note Mode 13h is graphical 256-color 320x200 (video memory at 0xA000:0000)
	xor	ah, ah
	mov	al, 0x13
	int	0x10
}

macro vid_mode_g_palette
{
; @brief Setup the VGA color palette
	mov	cx, 0x100		; There are 256 colors
	mov	bx, 2			; BX = 2 used for multiplication later

	.palette_next:
	mov	al, cl
	mov	dx, 0x03C8		; Port where to write color ID
	out	dx, al 			; Select color ID to change
	inc	dx			; Next port number is where we write RGB (0x03C9)

	; Set red channel
	out	dx, al

	; Set green channel
	xor	al, al
	out	dx, al

	; Set blue channel
	mov	al, cl
	and	al, 0xFF
	mul	bl
	out	dx, al

	; dec	bx
	loop	.palette_next
}

macro shutdown
{
; @brief TV shutdown animation

}

xy_to_idx:
; @brief Convert 2D coords X and Y to a 1D index in a linear array
; @param AX X position
; @param BX Y position
; @return AX Index of cell at (x,y)
	push	ax
	mov	ax, 320
	mul	bx
	pop	bx
	add	ax, bx
	ret

rand:
; @brief Generate a pseudo-random number using xorshift (DOI 10.18637/jss.v008.i14)
; @return AX Pseudo-random number
	mov     dx, WORD [seed]
	mov     ax, dx
        shl     ax, 7
        xor     ax, dx
        mov     dx, ax
        shr     dx, 9
        xor     dx, ax
        mov     ax, dx
        shl     ax, 8
        xor     ax, dx
	mov     WORD [seed], ax		; Save last generated pseudo-random number
	ret

main:
	vid_mode_g
	vid_mode_g_palette

	; The only location where segment regs are modified
	mov	bx, vid0_mem
	mov	gs, bx			; GS segment used to access video mem 0 (displayed)
	mov	bx, vid1_mem
	mov	fs, bx			; FS segment used to access video mem 1 (hidden)
	mov	bx, agnt_mem
	mov	es, bx			; ES segment holds agent structs
	mov	bx, stack_mem
	mov	ss, bx			; Stack lives in a 30KB region
	mov	sp, 0xFF		; A 255 byte stack is enough

	agent_init
	.simulate:

	; Draw to (hidden) vid1
	agent_sense_and_rotate
	agent_deposit_and_move
	trail_decay

	; Update (displayed) vid0 with vid1
	memcpy_vid1to0

	mov	bx, WORD [frame]
	cmp	bh, 0x0C		; Checks BX == 0x0FFF
	je	.main_end
	cmp	bh, 0x01		; Checks BX == 0x01FF
	jne	.effect_drunk_enable_skip
	.effect_drunk_enable:
	or	BYTE [effect], effect_drunk
	.effect_drunk_enable_skip:
	cmp	bh, 0x04		; Checks BX == 0x04FF
	jne	.effect_rose_enable_skip
	.effect_rose_enable:
	or	BYTE [effect], effect_rose
	.effect_rose_enable_skip:
	cmp	bh, 0x07		; Checks BX == 0x07FF
	jne	.effect_galaxy_enable_skip
	.effect_galaxy_enable:
	mov	BYTE [effect], effect_galaxy
	.effect_galaxy_enable_skip:

	inc	WORD [frame]		; Keep a frame count

	; Short sleep before next frame
	sleep
	jmp	.simulate

	.main_end:
	hlt

		db 0x00
aut		dd 0x01935711
times		510-($-$$) db 0		; Add 0s for padding until last 2 bytes
magic_number	dw 0xAA55
