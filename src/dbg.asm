; This contains all the code used for debugging/testing and is not part of the demo

macro vid_mode_g_palette_test
{
; @brief Write all colors to the screen to test the VGA color palette
	mov	cx, 320*200		; Each buffer is 320*200 bytes long
	xor	al, al

	xor	di, di
	.palette_test_next:
	mov	BYTE [fs:di], al
	inc	al
	inc	di
	loop	.palette_test_next
}

macro vid0_corners
{
; @brief Draw color in AL to every corner of the screen
; @param AL Color
;
; @example
;       rdtsc                           ; EDX:EAX = Number of CPU ticks since power-on
;       vid0_corners
;
	mov	BYTE [gs:0], al		; Top-Left Pixel = AL
	mov	BYTE [gs:319], al	; Top-Right Pixel = AL
	mov	BYTE [gs:320 * 199], al	; Bottom-Left Pixel = AL
	mov	BYTE [gs:320 * 200 - 1], al; Bottom-Right Pixel = AL
}
