; ====================================================================
; joystick (control port 2, CIA1 $DC01) -- active low
; bit2=left bit3=right bit4=fire
; ====================================================================

read_joystick:
    lda CIA1_PRB
    sta t0
    lda #0
    sta joy_left
    sta joy_right
    sta joy_fire
    lda t0
    and #%00000100
    bne @noleft
    lda #1
    sta joy_left
@noleft:
    lda t0
    and #%00001000
    bne @noright
    lda #1
    sta joy_right
@noright:
    lda t0
    and #%00010000
    bne @nofire
    lda #1
    sta joy_fire
@nofire:
    lda #0
    sta fire_edge
    lda joy_fire
    beq @noedge
    lda fire_prev
    bne @noedge
    lda #1
    sta fire_edge
@noedge:
    lda joy_fire
    sta fire_prev
    rts
